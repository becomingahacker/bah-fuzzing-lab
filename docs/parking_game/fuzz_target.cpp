// libFuzzer harness for parking-game puzzles.
//
// Input encoding: a sequence of 2-byte moves.
//   byte[2k+0] -> car index (1-based, mod num_cars)
//   byte[2k+1] -> direction (mod 4: Up, Down, Left, Right)
//
// Coverage is provided by -fsanitize=fuzzer's edge instrumentation over
// parking_game.hpp. A solved puzzle (objective car sees the wall ahead)
// triggers abort() so libFuzzer records it as a crash/finding.
//
// Build:
//   clang++ -std=c++17 -g -O1 -fsanitize=fuzzer,address fuzz_target.cpp -o pg_fuzz
//
// Run:
//   PG_MAP=maps/tokyo1.map ./pg_fuzz -max_len=256

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>

#include "map_parser.hpp"
#include "parking_game.hpp"

using namespace parking_game;

static State g_initial = [] {
  const char* path = std::getenv("PG_MAP");
  if (!path) path = "maps/tokyo1.map";
  std::ifstream f(path);
  if (!f) {
    fprintf(stderr, "cannot open map: %s\n", path);
    std::abort();
  }
  std::stringstream ss;
  ss << f.rdbuf();
  State s = parse_map(ss.str());
  fprintf(stderr, "Loaded %s (%zu cars):\n", path, s.cars().size());
  {
    State tmp = s;
    fprintf(stderr, "%s", Board(tmp).display().c_str());
  }
  return s;
}();

// Solved == objective car (index 1) has a clear path forward to the wall.
static bool is_solved(const Board& board) {
  const auto& [pos, car] = board.state().cars()[0];
  Direction fwd = car.orientation == Orientation::LeftRight ? Direction::Right
                                                            : Direction::Down;
  int offset = car.length;
  while (true) {
    auto p = shift(pos, fwd, offset);
    if (!p) return true;  // wall
    auto cell = board.get(*p);
    if (!cell) return true;       // wall (out of bounds)
    if (*cell != 0) return false; // blocked by another car
    ++offset;
  }
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  size_t num_cars = g_initial.cars().size();
  if (num_cars == 0) return 0;

  State state = g_initial;
  Board board(state);

  static const Direction kDirs[4] = {Direction::Up, Direction::Down,
                                     Direction::Left, Direction::Right};

  size_t n_moves = size / 2;
  for (size_t i = 0; i < n_moves; ++i) {
    // INSERT CODE HERE
  }

  if (is_solved(board)) {
    fprintf(stderr, "\nSOLVED in %zu moves:\n", n_moves);
    for (size_t i = 0; i < n_moves; ++i) {
      size_t car_idx = (data[2 * i] % num_cars) + 1;
      Direction dir = kDirs[data[2 * i + 1] % 4];
      fprintf(stderr, "  car %zu %s\n", car_idx, to_string(dir));
    }
    fprintf(stderr, "%s", board.display().c_str());
    std::abort();
  }

  return 0;
}
