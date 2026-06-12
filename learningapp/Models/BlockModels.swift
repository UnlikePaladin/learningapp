import SwiftUI

struct CellPosition: Hashable, Codable {
    let row: Int
    let col: Int
}

struct BlockShape: Identifiable, Hashable, Codable {
    let id: UUID
    let cells: [CellPosition]

    static func == (lhs: BlockShape, rhs: BlockShape) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func shapeView(cellSize: CGFloat) -> some View {
        let minRow = cells.map(\.row).min() ?? 0
        let minCol = cells.map(\.col).min() ?? 0
        let maxRow = cells.map(\.row).max() ?? 0
        let maxCol = cells.map(\.col).max() ?? 0
        let rows = maxRow - minRow + 1
        let cols = maxCol - minCol + 1

        return ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: CGFloat(cols) * cellSize, height: CGFloat(rows) * cellSize)
            ForEach(cells, id: \.self) { cell in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color("Darkgreen"))
                    .frame(width: cellSize - 2, height: cellSize - 2)
                    .offset(
                        x: CGFloat(cell.col - minCol) * cellSize + 1,
                        y: CGFloat(cell.row - minRow) * cellSize + 1
                    )
            }
        }
        .frame(width: CGFloat(cols) * cellSize, height: CGFloat(rows) * cellSize)
    }

    static func allShapesPool() -> [BlockShape] {
        let shapes: [[CellPosition]] = [
            // I-horizontal
            [CellPosition(row: 0, col: 0), CellPosition(row: 0, col: 1), CellPosition(row: 0, col: 2), CellPosition(row: 0, col: 3)],
            // I-vertical
            [CellPosition(row: 0, col: 0), CellPosition(row: 1, col: 0), CellPosition(row: 2, col: 0), CellPosition(row: 3, col: 0)],
            // O
            [CellPosition(row: 0, col: 0), CellPosition(row: 0, col: 1), CellPosition(row: 1, col: 0), CellPosition(row: 1, col: 1)],
            // T
            [CellPosition(row: 0, col: 0), CellPosition(row: 0, col: 1), CellPosition(row: 0, col: 2), CellPosition(row: 1, col: 1)],
            // L
            [CellPosition(row: 0, col: 0), CellPosition(row: 1, col: 0), CellPosition(row: 2, col: 0), CellPosition(row: 2, col: 1)],
            // J
            [CellPosition(row: 0, col: 1), CellPosition(row: 1, col: 1), CellPosition(row: 2, col: 0), CellPosition(row: 2, col: 1)],
            // S
            [CellPosition(row: 0, col: 1), CellPosition(row: 0, col: 2), CellPosition(row: 1, col: 0), CellPosition(row: 1, col: 1)],
            // Z
            [CellPosition(row: 0, col: 0), CellPosition(row: 0, col: 1), CellPosition(row: 1, col: 1), CellPosition(row: 1, col: 2)],
            // Single
            [CellPosition(row: 0, col: 0)],
            // Domino-H
            [CellPosition(row: 0, col: 0), CellPosition(row: 0, col: 1)],
            // Domino-V
            [CellPosition(row: 0, col: 0), CellPosition(row: 1, col: 0)],
            // Trio-L
            [CellPosition(row: 0, col: 0), CellPosition(row: 1, col: 0), CellPosition(row: 1, col: 1)],
            // Corner
            [CellPosition(row: 0, col: 0), CellPosition(row: 0, col: 1), CellPosition(row: 1, col: 0)],
            // Trio-I
            [CellPosition(row: 0, col: 0), CellPosition(row: 0, col: 1), CellPosition(row: 0, col: 2)],
        ]
        return shapes.map { BlockShape(id: UUID(), cells: $0) }
    }

    static func randomSet(count: Int) -> [BlockShape] {
        let pool = allShapesPool()
        return (0..<count).map { _ in pool.randomElement()! }
    }
}
