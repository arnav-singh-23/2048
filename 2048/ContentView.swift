//
//  ContentView.swift
//  2048
//
//  Created by ARNAV SINGH on 03/11/26.
//

import SwiftUI
import Combine

struct Tile: Identifiable {
    let id = UUID()
    var value: Int
    var row: Int
    var col: Int
}

enum Direction { case up, down, left, right }

final class GameModel: ObservableObject {
    let size = 4
    @Published private(set) var tiles: [Tile] = []
    @Published private(set) var score = 0
    @Published private(set) var isGameOver = false
    private var busy = false
    private var generation = 0

    init() { reset() }

    func reset() {
        generation += 1
        busy = false
        tiles = []
        score = 0
        isGameOver = false
        spawn()
        spawn()
    }

    private func cell(_ d: Direction, line i: Int, pos j: Int) -> (row: Int, col: Int) {
        switch d {
        case .left:  return (i, j)
        case .right: return (i, size - 1 - j)
        case .up:    return (j, i)
        case .down:  return (size - 1 - j, i)
        }
    }
    func move(_ dir: Direction) {
            guard !busy, !isGameOver else { return }
            var next = tiles
            var index: [Int: Int] = [:]
            for (x, t) in tiles.enumerated() { index[t.row * size + t.col] = x }
     
            var absorbed = Set<UUID>(), doubled = Set<UUID>()
            var changed = false, gained = 0
     
            for i in 0..<size {
                var target = 0
                var last: Int? = nil
                var lastMerged = false
                for j in 0..<size {
                    let (r, c) = cell(dir, line: i, pos: j)
                    guard let k = index[r * size + c] else { continue }
     
                    if let l = last, !lastMerged, next[l].value == next[k].value {
                        next[k].row = next[l].row; next[k].col = next[l].col
                        absorbed.insert(next[k].id); doubled.insert(next[l].id)
                        gained += next[l].value * 2
                        lastMerged = true; changed = true
                    } else {
                        let (tr, tc) = cell(dir, line: i, pos: target)
                        if next[k].row != tr || next[k].col != tc { changed = true }
                        next[k].row = tr; next[k].col = tc
                        last = k; lastMerged = false; target += 1
                    }
                }
            }
     
            guard changed else { return }
     
            busy = true
            let gen = generation
            withAnimation(.easeInOut(duration: 0.12)) { tiles = next }
            score += gained
     
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [self] in
                guard gen == generation else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    tiles.removeAll { absorbed.contains($0.id) }
                    for k in tiles.indices where doubled.contains(tiles[k].id) { tiles[k].value *= 2 }
                    spawn()
                }
                isGameOver = !hasMoves()
                busy = false
            }
        }
    private func spawn() {
        let taken = Set(tiles.map { $0.row * size + $0.col })
        guard let spot = (0..<size * size).filter({ !taken.contains($0) }).randomElement() else { return }
        tiles.append(Tile(value: Int.random(in: 0..<10) == 0 ? 4 : 2, row: spot / size, col: spot % size))
    }

    private func hasMoves() -> Bool {
        guard tiles.count == size * size else { return true }
        for a in tiles {
            for b in tiles where a.id != b.id && a.value == b.value {
                if abs(a.row - b.row) + abs(a.col - b.col) == 1 { return true }
            }
        }
        return false
    }
}

struct TileView: View {
    let value: Int
    private var color: Color {
        switch value {
        case 2: return Color(red: 0.93, green: 0.89, blue: 0.85)
        case 4: return Color(red: 0.93, green: 0.88, blue: 0.78)
        case 8: return Color(red: 0.95, green: 0.69, blue: 0.47)
        case 16: return Color(red: 0.96, green: 0.58, blue: 0.39)
        case 32: return Color(red: 0.96, green: 0.48, blue: 0.37)
        case 64: return Color(red: 0.96, green: 0.37, blue: 0.23)
        case 128: return Color(red: 0.93, green: 0.81, blue: 0.45)
        case 256: return Color(red: 0.93, green: 0.80, blue: 0.38)
        case 512: return Color(red: 0.93, green: 0.78, blue: 0.31)
        case 1024: return Color(red: 0.93, green: 0.77, blue: 0.25)
        default: return Color(red: 0.93, green: 0.76, blue: 0.18)
        }
    }
    var body: some View {
        RoundedRectangle(cornerRadius: 8).fill(color)
            .overlay(Text("\(value)").font(.system(size: 36, weight: .bold))
                .minimumScaleFactor(0.4).foregroundColor(value <= 4 ? .gray : .white))
    }
}

struct GameView: View {
    @StateObject private var game = GameModel()
    @AppStorage("best") private var best = 0
    private let gap: CGFloat = 8

    var body: some View {
        VStack(spacing: 16) {
            Text("Score \(game.score)   Best \(best)").font(.headline)

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let cell = (side - gap * 5) / 4
                let pos = { (n: Int) in gap + CGFloat(n) * (cell + gap) }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.7))
                    ForEach(0..<16, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.8))
                            .frame(width: cell, height: cell)
                            .offset(x: pos(i % 4), y: pos(i / 4))
                    }
                    ForEach(game.tiles) { t in
                        TileView(value: t.value)
                            .frame(width: cell, height: cell)
                            .offset(x: pos(t.col), y: pos(t.row))
                            .zIndex(Double(t.value))
                            .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    }
                }
                .frame(width: side, height: side)
                .gesture(DragGesture(minimumDistance: 20).onEnded { v in
                    let dx = v.translation.width, dy = v.translation.height
                    if abs(dx) > abs(dy) { game.move(dx > 0 ? .right : .left) }
                    else { game.move(dy > 0 ? .down : .up) }
                    best = max(best, game.score)
                })
            }
            .aspectRatio(1, contentMode: .fit)

            Button("New Game") { game.reset() }
        }
        .padding()
        .sensoryFeedback(.impact(weight: .medium), trigger: game.score)
        .sensoryFeedback(trigger: game.isGameOver) { _, isOver in         
            isOver ? .error : nil
        }
        .alert("Game over", isPresented: .constant(game.isGameOver)) {
            Button("Try again") { game.reset() }
        }
    }
}

struct ContentView: View {
    var body: some View {
        GameView()
    }
}

#Preview {
    ContentView()
}
