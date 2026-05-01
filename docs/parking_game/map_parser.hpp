// Map parser for parking-game puzzles. Port of the Rust parse_map().

#pragma once

#include <algorithm>
#include <map>
#include <sstream>
#include <string>
#include <vector>

#include "parking_game.hpp"

namespace parking_game {

inline State parse_map(const std::string& raw) {
  std::vector<std::string> lines;
  {
    std::istringstream ss(raw);
    std::string line;
    while (std::getline(ss, line)) {
      // trim ASCII whitespace
      size_t a = line.find_first_not_of(" \t\r\n");
      size_t b = line.find_last_not_of(" \t\r\n");
      if (a == std::string::npos) continue;
      lines.push_back(line.substr(a, b - a + 1));
    }
  }
  int rows = static_cast<int>(lines.size());
  int cols = static_cast<int>(lines[0].size());

  struct Entry {
    Position pos;
    Orientation orient;
    int len;
  };
  std::map<char, Entry> cars;

  std::optional<char> prev;
  for (int r = 0; r < rows; ++r) {
    for (int c = 0; c < cols; ++c) {
      char ch = lines[r][c];
      if (prev) {
        auto it = cars.find(*prev);
        if (it != cars.end()) {
          it->second.len += 1;
        } else if (*prev == ch) {
          cars[*prev] = Entry{{r, c - 1}, Orientation::LeftRight, 1};
        } else {
          cars[*prev] = Entry{{r, c - 1}, Orientation::UpDown, 1};
        }
        prev = (ch == '.') ? std::nullopt : std::optional<char>(ch);
      } else if (ch != '.') {
        prev = ch;
      }
    }
    if (prev) {
      auto it = cars.find(*prev);
      if (it != cars.end()) {
        it->second.len += 1;
      } else {
        cars[*prev] = Entry{{r, cols - 1}, Orientation::UpDown, 1};
      }
      prev = std::nullopt;
    }
  }

  State state = State::empty(rows, cols);
  Board board(state);

  // Objective car 'o' first, then lexicographic order.
  Entry obj = cars.at('o');
  cars.erase('o');
  board.add_car(obj.pos, Car(obj.len, obj.orient));
  for (const auto& [name, e] : cars) {
    board.add_car(e.pos, Car(e.len, e.orient));
  }
  return state;
}

}  // namespace parking_game
