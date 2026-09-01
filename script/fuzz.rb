# frozen_string_literal: true
#
# script/game_state_fuzzer.rb
#
# Randomized property-based fuzzer for GameState. Uses your REAL Player,
# Move, and Deck models -- including Move's validations -- so illegal moves
# get rejected the same way they would in production. Each fuzzed game runs
# inside a DB transaction that's rolled back afterwards, so nothing sticks
# around in your database.
#
# RUN (from your Rails root):
#   bin/rails runner script/game_state_fuzzer.rb [num_games] [max_players] [seed]
#   bin/rails runner script/game_state_fuzzer.rb 300 6 12345
#   bin/rails runner script/game_state_fuzzer.rb 300 6 12345 --chaos
#
# BEFORE RUNNING: fill in Fuzz::Setup below so it matches your schema. That's
# the only part you should need to touch.

module Fuzz
  module Setup
    # Create a Game plus `player_count` Players attached to it, using the
    # given seed/starting_lives. Must return the persisted Game.
    # ---- ADJUST THIS to your actual associations/attributes ----
    def self.build_game(seed:, starting_lives:, player_count:)
      game = Game.create!(seed: seed, starting_lives: starting_lives)
      player_count.times { |i| game.players.create!(name: "Fuzz Player #{i}") }
      game
    end

    # Attempt to record a move. Return the (possibly invalid/unpersisted)
    # Move -- use `.create`, not `.create!`, so validation failures come back
    # as an object with `.errors` instead of an exception, and the fuzzer can
    # tell "rejected by validation" apart from "blew up unexpectedly".
    # `value` is an Integer bid during the bidding phase, or a card (whatever
    # type your Deck deals) during the card-playing phase.
    # ---- ADJUST THIS to your actual association/attribute names ----
    def self.record_move(game, player_id:, value:)
      game.moves.create(player_id: player_id, value: value)
    end
  end
end

# ---------------------------------------------------------------------------
# Fuzzer core -- shouldn't need changes below this line
# ---------------------------------------------------------------------------

class FuzzFailure < StandardError
  attr_reader :seed, :move_log

  def initialize(msg, seed:, move_log:)
    @seed = seed
    @move_log = move_log
    super(msg)
  end
end

def dump_repro(failure)
  puts "\n--- REPRODUCTION ---"
  puts "seed: #{failure.seed}"
  puts "moves (player_id, value):"
  failure.move_log.each { |pid, val| puts "  [#{pid.inspect}, #{val.inspect}]" }
  puts "Rebuild with Fuzz::Setup.build_game(seed: #{failure.seed}, ...) and replay these moves"
  puts "via Fuzz::Setup.record_move in order to reproduce."
  puts "--------------------\n"
end

def check_invariants!(state, seed, move_log)
  fail_with = ->(msg) { raise FuzzFailure.new(msg, seed: seed, move_log: move_log) }

  alive = state.alive_players
  # alive_players.empty? is now a legitimate terminal state (everyone can
  # lose simultaneously) -- not checked as an invariant violation here.

  if state.turn_player_index && !alive.empty?
    unless (0...alive.size).cover?(state.turn_player_index)
      fail_with.call("turn_player_index=#{state.turn_player_index} out of range for #{alive.size} alive players")
    end
  end

  state.bids.each_key do |pid|
    fail_with.call("bid recorded for non-alive/unknown player #{pid}") unless alive.include?(pid)
  end

  state.tricks_won.each_key do |pid|
    fail_with.call("trick win recorded for non-alive/unknown player #{pid}") unless alive.include?(pid)
  end

  state.lives.each do |pid, v|
    fail_with.call("life total for #{pid} is not an Integer: #{v.inspect}") unless v.is_a?(Integer)
  end

  alive.each do |pid|
    fail_with.call("alive player #{pid} has no hand entry") if state.hands[pid].nil?
  end
end

def play_random_game(seed:, player_count:, starting_lives:, max_moves: 3000, chaos: false)
  move_log = []
  moves_made = 0
  state = nil

  # GameState.for caches on "game_state/#{game.id}/#{last_move_id}". That's a
  # safe key in production (ids never get reused), but this fuzzer rolls
  # back every game's transaction, and Rails.cache is NOT part of that
  # rollback. On backends where a rolled-back id can be reused (SQLite's
  # rowid reuse is the classic case), a later game can collide with an
  # earlier game's cache key and get served a stale, unrelated state. Clear
  # first so each game starts from a guaranteed cache miss.
  Rails.cache.clear

  ActiveRecord::Base.transaction(requires_new: true) do
    game = Fuzz::Setup.build_game(seed: seed, starting_lives: starting_lives, player_count: player_count)
    rng = Random.new(seed)

    loop do
      state = GameState.for(game)
      break if state.alive_players.size <= 1
      break if moves_made >= max_moves

      pid = state.turn_player_id

      if state.bidding_phase?
        value = rng.rand(0..state.hand_size)
      else
        hand = state.hands[pid] || []
        if hand.empty?
          raise FuzzFailure.new("player #{pid} is up to play a card but has an empty/missing hand",
                                 seed: seed, move_log: move_log)
        end
        value = hand.sample(random: rng)
      end

      before_round = state.round
      before_hand_size = state.hands[pid]&.size

      move = Fuzz::Setup.record_move(game, player_id: pid, value: value)
      move_log << [pid, value]

      unless move.persisted?
        raise FuzzFailure.new(
          "legal-looking move (player=#{pid}, value=#{value.inspect}) was rejected by validation: " \
          "#{move.errors.full_messages.join(', ')}",
          seed: seed, move_log: move_log
        )
      end

      after = GameState.for(game)

      if !state.bidding_phase? && after.round == before_round &&
         after.hands[pid] && after.current_trick.any? { |p, _| p == pid }
        got = after.hands[pid].size
        expected = before_hand_size - 1
        if got != expected
          raise FuzzFailure.new(
            "player #{pid}'s hand size was #{got}, expected #{expected} after playing #{value.inspect} " \
            "(possible bug: Array#- silently no-ops if the card isn't found in hand)",
            seed: seed, move_log: move_log
          )
        end
      end

      check_invariants!(after, seed, move_log)
      moves_made += 1
    end

    probe_illegal_moves(game, state) if chaos && state

    raise ActiveRecord::Rollback
  end

  { moves: moves_made, final_round: state&.round, final_lives: state&.lives }
rescue FuzzFailure
  raise
rescue StandardError => e
  raise FuzzFailure.new("#{e.class}: #{e.message}\n  #{e.backtrace&.first(6)&.join("\n  ")}",
                         seed: seed, move_log: move_log)
end

# Probes a few clearly-illegal moves against the *live* (about-to-be-rolled-
# back) game and reports what happens. Since Move has real validations, the
# expected/good outcome is "rejected" -- this flags cases where an illegal
# move slips through and would reach GameState.
def probe_illegal_moves(game, state)
  return if state.alive_players.empty?

  probes = []

  if state.bidding_phase?
    pid = state.turn_player_id
    probes << ["bid way out of range", pid, state.hand_size + 999]
    probes << ["negative bid", pid, -5]
  else
    pid = state.turn_player_id
    probes << ["card not in hand", pid, "ZZ99"]
    other = (state.hands.keys - [pid]).sample
    probes << ["out-of-turn play", other, state.hands[other]&.first] if other && state.hands[other]&.any?
  end

  probes.each do |label, probe_pid, value|
    next if probe_pid.nil? || value.nil?

    ActiveRecord::Base.transaction(requires_new: true) do
      begin
        move = Fuzz::Setup.record_move(game, player_id: probe_pid, value: value)
        if move.persisted?
          puts "[chaos] #{label}: NOT rejected -- Move accepted it (#{value.inspect})"
        else
          puts "[chaos] #{label}: rejected as expected (#{move.errors.full_messages.join(', ')})"
        end
      rescue StandardError => e
        puts "[chaos] #{label}: raised #{e.class}: #{e.message}"
      ensure
        raise ActiveRecord::Rollback
      end
    end
  end
end

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

num_games   = (ARGV[0] || 200).to_i
max_players = (ARGV[1] || 6).to_i
base_seed   = (ARGV[2] || Random.new_seed).to_i
chaos       = ARGV.include?("--chaos")

puts "Fuzzing GameState: #{num_games} games, up to #{max_players} players, base_seed=#{base_seed}#{' (chaos on)' if chaos}"

failures = 0

num_games.times do |i|
  seed = base_seed + i
  rng = Random.new(seed)
  player_count = rng.rand(2..max_players)
  starting_lives = rng.rand(1..5)

  begin
    play_random_game(
      seed: seed,
      player_count: player_count,
      starting_lives: starting_lives,
      chaos: chaos
    )
    print "." if ((i + 1) % 50).zero?
  rescue FuzzFailure => f
    failures += 1
    puts "\n[FAIL] seed=#{seed} (players=#{player_count}, lives=#{starting_lives}): #{f.message}"
    dump_repro(f)
  end
end

puts "\nDone. #{num_games - failures}/#{num_games} games completed without a detected invariant violation."
exit(failures.zero? ? 0 : 1)
