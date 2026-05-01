// parking-game: a library recreating the rules of Thinkfun's "Rush Hour".
//
// C++ port of the Rust crate. Implements movement rules (intersection and
// bounds checks); gameplay is left to the caller.

#pragma once

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

namespace parking_game {

enum class Orientation : uint8_t { UpDown, LeftRight };

enum class Direction : uint8_t { Up, Down, Left, Right };

inline Direction operator-(Direction d) {
  switch (d) {
    case Direction::Up:    return Direction::Down;
    case Direction::Down:  return Direction::Up;
    case Direction::Left:  return Direction::Right;
    case Direction::Right: return Direction::Left;
  }
  __builtin_unreachable();
}

inline const char* to_string(Direction d) {
  switch (d) {
    case Direction::Up:    return "up";
    case Direction::Down:  return "down";
    case Direction::Left:  return "left";
    case Direction::Right: return "right";
  }
  __builtin_unreachable();
}

struct Car {
  int length;
  Orientation orientation;

  Car(int len, Orientation o) : length(len), orientation(o) {
    if (len < 1) throw std::invalid_argument("Car length must be >= 1");
  }
};

struct Position {
  int row;
  int column;

  bool operator==(const Position& o) const {
    return row == o.row && column == o.column;
  }
};

struct Dimensions {
  int rows;
  int columns;

  Dimensions(int r, int c) : rows(r), columns(c) {
    if (r <= 0 || c <= 0)
      throw std::invalid_argument("Dimensions must have nonzero area");
  }

  std::optional<size_t> as_index(Position p) const {
    if (p.row < 0 || p.row >= rows || p.column < 0 || p.column >= columns)
      return std::nullopt;
    return static_cast<size_t>(p.row) * static_cast<size_t>(columns) +
           static_cast<size_t>(p.column);
  }
};

inline std::optional<Position> shift(Position p, Direction dir, int by) {
  switch (dir) {
    case Direction::Up: {
      int nr = p.row - by;
      if (nr < 0) return std::nullopt;
      return Position{nr, p.column};
    }
    case Direction::Down:
      return Position{p.row + by, p.column};
    case Direction::Left: {
      int nc = p.column - by;
      if (nc < 0) return std::nullopt;
      return Position{p.row, nc};
    }
    case Direction::Right:
      return Position{p.row, p.column + by};
  }
  __builtin_unreachable();
}

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

struct InvalidStateError : std::runtime_error {
  using std::runtime_error::runtime_error;
};

struct InvalidPositionError : InvalidStateError {
  size_t idx;
  Position position;
  InvalidPositionError(size_t i, Position p)
      : InvalidStateError("car at invalid position"), idx(i), position(p) {}
};

struct OverlapError : InvalidStateError {
  size_t idx1, idx2;
  Position position;
  OverlapError(size_t a, size_t b, Position p)
      : InvalidStateError("cars overlap"), idx1(a), idx2(b), position(p) {}
};

struct InvalidMoveError : std::runtime_error {
  size_t car;
  Direction dir;
  InvalidMoveError(const char* msg, size_t c, Direction d)
      : std::runtime_error(msg), car(c), dir(d) {}
};

struct InvalidCarError : InvalidMoveError {
  InvalidCarError(size_t c, Direction d)
      : InvalidMoveError("car doesn't exist", c, d) {}
};

struct InvalidDirectionError : InvalidMoveError {
  InvalidDirectionError(size_t c, Direction d)
      : InvalidMoveError("orientation forbids direction", c, d) {}
};

struct InvalidFinalPositionError : InvalidMoveError {
  InvalidFinalPositionError(size_t c, Direction d)
      : InvalidMoveError("final position out of bounds", c, d) {}
};

struct IntersectsError : InvalidMoveError {
  Position at;
  size_t other;
  IntersectsError(size_t c, Direction d, Position p, size_t o)
      : InvalidMoveError("intersects another car", c, d), at(p), other(o) {}
};

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class Board;

class State {
 public:
  static State empty(int rows, int cols) { return State(Dimensions(rows, cols)); }

  const Dimensions& dimensions() const { return dim_; }
  const std::vector<std::pair<Position, Car>>& cars() const { return cars_; }
  std::vector<std::pair<Position, Car>>& cars_mut() { return cars_; }

  size_t hash_positions() const {
    size_t h = 0;
    for (const auto& [p, c] : cars_) {
      size_t k = static_cast<size_t>(p.row) * 73856093u ^
                 static_cast<size_t>(p.column) * 19349663u;
      h ^= k + 0x9e3779b9 + (h << 6) + (h >> 2);
    }
    return h;
  }

 private:
  explicit State(Dimensions d) : dim_(d) {}
  Dimensions dim_;
  std::vector<std::pair<Position, Car>> cars_;
  friend class Board;
};

// ---------------------------------------------------------------------------
// Board
// ---------------------------------------------------------------------------

class Board {
 public:
  explicit Board(State& state) : state_(state) {
    size_t n = static_cast<size_t>(state_.dim_.rows) *
               static_cast<size_t>(state_.dim_.columns);
    concrete_.assign(n, 0);  // 0 == empty; 1-based car index otherwise
    for (size_t i = 0; i < state_.cars_.size(); ++i) {
      add_car_concrete(i + 1, state_.cars_[i].first, state_.cars_[i].second);
    }
  }

  const State& state() const { return state_; }
  const std::vector<size_t>& concrete() const { return concrete_; }

  // Returns nullopt if out of bounds; otherwise the cell value (0 == empty).
  std::optional<size_t> get(Position p) const {
    auto idx = state_.dim_.as_index(p);
    if (!idx) return std::nullopt;
    return concrete_[*idx];
  }

  size_t add_car(Position pos, Car car) {
    size_t idx = state_.cars_.size() + 1;
    add_car_concrete(idx, pos, car);
    state_.cars_.emplace_back(pos, car);
    return idx;
  }

  Position shift_car(size_t car_idx, Direction dir) {
    if (car_idx == 0 || car_idx > state_.cars_.size())
      throw InvalidCarError(car_idx, dir);

    size_t i = car_idx - 1;
    Position pos = state_.cars_[i].first;
    Car actual = state_.cars_[i].second;

    std::optional<Position> deleted, inserted;
    bool backward =
        (dir == Direction::Up && actual.orientation == Orientation::UpDown) ||
        (dir == Direction::Left && actual.orientation == Orientation::LeftRight);
    bool forward =
        (dir == Direction::Down && actual.orientation == Orientation::UpDown) ||
        (dir == Direction::Right && actual.orientation == Orientation::LeftRight);

    if (backward) {
      deleted = shift(pos, -dir, actual.length - 1);
      inserted = shift(pos, dir, 1);
    } else if (forward) {
      deleted = pos;
      inserted = shift(pos, dir, actual.length);
    } else {
      throw InvalidDirectionError(car_idx, dir);
    }

    if (!deleted || !inserted)
      throw InvalidFinalPositionError(car_idx, dir);

    auto del_idx = state_.dim_.as_index(*deleted);
    auto ins_idx = state_.dim_.as_index(*inserted);
    if (!del_idx || !ins_idx || *del_idx == *ins_idx)
      throw InvalidFinalPositionError(car_idx, dir);

    if (concrete_[*ins_idx] != 0)
      throw IntersectsError(car_idx, dir, *inserted, concrete_[*ins_idx]);

    concrete_[*ins_idx] = concrete_[*del_idx];
    concrete_[*del_idx] = 0;

    Position np = *shift(pos, dir, 1);
    state_.cars_[i].first = np;
    return np;
  }

  std::string display() const {
    std::string out;
    size_t idx = 0;
    for (int r = 0; r < state_.dim_.rows; ++r) {
      for (int c = 0; c < state_.dim_.columns; ++c) {
        size_t v = concrete_[idx++];
        if (v == 0) {
          out += " . ";
        } else {
          char buf[8];
          snprintf(buf, sizeof(buf), "%2zu ", v);
          out += buf;
        }
      }
      out += '\n';
    }
    return out;
  }

 private:
  void add_car_concrete(size_t idx, Position pos, const Car& car) {
    int dr = car.orientation == Orientation::UpDown ? 1 : 0;
    int dc = car.orientation == Orientation::LeftRight ? 1 : 0;

    Position base = pos;
    for (int k = 0; k < car.length; ++k) {
      auto ci = state_.dim_.as_index(base);
      if (!ci) throw InvalidPositionError(idx, base);
      if (concrete_[*ci] != 0) throw OverlapError(concrete_[*ci], idx, base);
      base = Position{base.row + dr, base.column + dc};
    }
    base = pos;
    for (int k = 0; k < car.length; ++k) {
      concrete_[*state_.dim_.as_index(base)] = idx;
      base = Position{base.row + dr, base.column + dc};
    }
  }

  State& state_;
  std::vector<size_t> concrete_;
};

}  // namespace parking_game
