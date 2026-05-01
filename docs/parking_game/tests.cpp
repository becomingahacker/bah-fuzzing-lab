// Unit tests for the parking-game C++ port.

#include <cassert>
#include <cstdio>

#include "map_parser.hpp"
#include "parking_game.hpp"

using namespace parking_game;

static void test_simple_board() {
  State state = State::empty(2, 2);
  Board board(state);

  size_t idx = board.add_car({0, 0}, Car(1, Orientation::LeftRight));
  assert(idx == 1);
  assert(*board.get({0, 0}) == 1);

  bool threw = false;
  try { board.add_car({2, 0}, Car(1, Orientation::UpDown)); }
  catch (const InvalidPositionError& e) { threw = true; assert(e.idx == 2); }
  assert(threw);

  threw = false;
  try { board.add_car({0, 0}, Car(1, Orientation::UpDown)); }
  catch (const OverlapError& e) {
    threw = true;
    assert(e.idx1 == 1 && e.idx2 == 2);
  }
  assert(threw);

  board.shift_car(idx, Direction::Right);
  assert(*board.get({0, 1}) == 1);
  assert(*board.get({0, 0}) == 0);

  board.shift_car(idx, Direction::Left);
  assert(*board.get({0, 0}) == 1);
  assert(*board.get({0, 1}) == 0);

  size_t idx2 = board.add_car({0, 1}, Car(1, Orientation::UpDown));
  assert(idx2 == 2);

  board.shift_car(idx2, Direction::Down);
  assert(*board.get({1, 1}) == 2);
  board.shift_car(idx2, Direction::Up);
  assert(*board.get({0, 1}) == 2);

  threw = false;
  try { board.shift_car(3, Direction::Right); }
  catch (const InvalidCarError&) { threw = true; }
  assert(threw);

  threw = false;
  try { board.shift_car(idx2, Direction::Up); }
  catch (const InvalidFinalPositionError&) { threw = true; }
  assert(threw);

  threw = false;
  try { board.shift_car(idx2, Direction::Right); }
  catch (const InvalidDirectionError&) { threw = true; }
  assert(threw);

  threw = false;
  try { board.shift_car(1, Direction::Right); }
  catch (const IntersectsError& e) {
    threw = true;
    assert(e.other == 2);
    assert((e.at == Position{0, 1}));
  }
  assert(threw);

  printf("test_simple_board: OK\n");
}

static void test_multi_board() {
  State state = State::empty(5, 5);
  Board board(state);
  size_t idx = board.add_car({0, 0}, Car(3, Orientation::UpDown));
  assert(idx == 1);

  board.shift_car(idx, Direction::Down);
  assert(*board.get({0, 0}) == 0);
  assert(*board.get({1, 0}) == 1);
  assert(*board.get({2, 0}) == 1);
  assert(*board.get({3, 0}) == 1);
  assert(*board.get({4, 0}) == 0);

  printf("test_multi_board: OK\n");
}

static void test_parse_map() {
  State s = parse_map(
      R"(
      ......
      ......
      .oo1..
      .221.3
      .4.1.3
      .455.3
      )");
  assert(s.cars().size() == 6);
  assert((s.cars()[0].first == Position{2, 1}));  // objective car
  assert(s.cars()[0].second.orientation == Orientation::LeftRight);
  assert(s.cars()[0].second.length == 2);

  printf("test_parse_map: OK\n");
}

static void test_hash_distinguish() {
  State a = parse_map("33oo22.");
  State b = parse_map("33oo.22");
  assert(a.hash_positions() != b.hash_positions());
  printf("test_hash_distinguish: OK\n");
}

int main() {
  test_simple_board();
  test_multi_board();
  test_parse_map();
  test_hash_distinguish();
  printf("All tests passed.\n");
  return 0;
}
