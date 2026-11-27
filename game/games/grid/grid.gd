class_name Grid
extends RefCounted
## Square-grid geometry shared by the grid games (DISCUSSION.md section 31): Four in a
## Row first, then Reversi, Checkers, Dots and Boxes and Hnefatafl. Pure data, no
## screen code.
##
## Cells are numbered row by row from the bottom left: cell = row * cols + col, with
## row 0 at the bottom. (For a dropping game the bottom row is where discs land.)

## The four line directions as [d_col, d_row]: across, up, up-right, up-left.
const LINE_DIRS := [[1, 0], [0, 1], [1, 1], [-1, 1]]
## All eight neighbour directions, for games that look every way (Reversi).
const ALL_DIRS := [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]]


static func cell(cols: int, col: int, row: int) -> int:
	return row * cols + col


static func col_of(cols: int, c: int) -> int:
	return c % cols


static func row_of(cols: int, c: int) -> int:
	return floori(c / float(cols))


static func inside(cols: int, rows: int, col: int, row: int) -> bool:
	return col >= 0 and col < cols and row >= 0 and row < rows


## Every straight run of `length` cells (across, up and down, and both diagonals),
## each as the cells in order. A 7 × 6 board has 69 runs of four.
static func lines(cols: int, rows: int, length: int) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for row in rows:
		for col in cols:
			for d: Array in LINE_DIRS:
				var end_col: int = col + d[0] * (length - 1)
				var end_row: int = row + d[1] * (length - 1)
				if not inside(cols, rows, end_col, end_row):
					continue
				var run := PackedInt32Array()
				for k in length:
					run.append(cell(cols, col + d[0] * k, row + d[1] * k))
				out.append(run)
	return out
