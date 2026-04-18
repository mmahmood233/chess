import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;

// ── Classic board colours (lichess palette) ─────────────────────────────────
const _lightSquare = Color(0xFFF0D9B5);
const _darkSquare = Color(0xFFB58863);
const _selectedLight = Color(0xFFF6F669);
const _selectedDark = Color(0xFFBBCA2A);
const _checkLight = Color(0xFFFF6B6B);
const _checkDark = Color(0xFFCC4444);
const _lastMoveLight = Color(0xFFCDD26A);
const _lastMoveDark = Color(0xFFAAA23A);

class CustomChessBoard extends StatelessWidget {
  final String fen;
  final Function(String from, String to, {String? promotion})? onMove;
  final bool isWhite;
  final bool isMyTurn;

  const CustomChessBoard({
    super.key,
    required this.fen,
    this.onMove,
    required this.isWhite,
    required this.isMyTurn,
  });

  @override
  Widget build(BuildContext context) {
    return _ChessBoardWidget(
      fen: fen,
      onMove: onMove,
      isWhite: isWhite,
      isMyTurn: isMyTurn,
    );
  }
}

class _ChessBoardWidget extends StatefulWidget {
  final String fen;
  final Function(String from, String to, {String? promotion})? onMove;
  final bool isWhite;
  final bool isMyTurn;

  const _ChessBoardWidget({
    required this.fen,
    this.onMove,
    required this.isWhite,
    required this.isMyTurn,
  });

  @override
  State<_ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<_ChessBoardWidget> {
  String? _selectedSquare;       // algebraic of selected piece
  Set<String> _legalTargets = {}; // algebraic destinations for selected piece
  String? _lastMoveFrom;
  String? _lastMoveTo;
  late chess_lib.Chess _chess;

  @override
  void initState() {
    super.initState();
    _chess = chess_lib.Chess.fromFEN(widget.fen);
  }

  @override
  void didUpdateWidget(_ChessBoardWidget old) {
    super.didUpdateWidget(old);
    if (old.fen != widget.fen) {
      _chess = chess_lib.Chess.fromFEN(widget.fen);
      setState(() {
        _selectedSquare = null;
        _legalTargets = {};
      });
    }
    // If it stops being our turn, deselect
    if (old.isMyTurn && !widget.isMyTurn) {
      setState(() {
        _selectedSquare = null;
        _legalTargets = {};
      });
    }
  }

  // ── Chess helpers ────────────────────────────────────────────────────────────

  String? _findCheckedKingSquare() {
    if (!_chess.in_check) return null;
    final kingColor = _chess.turn;
    for (var file = 0; file < 8; file++) {
      for (var rank = 0; rank < 8; rank++) {
        final sq = '${String.fromCharCode(97 + file)}${rank + 1}';
        final piece = _chess.get(sq);
        if (piece != null &&
            piece.type.name == 'k' &&
            piece.color == kingColor) {
          return sq;
        }
      }
    }
    return null;
  }

  Set<String> _legalMovesFrom(String square) {
    try {
      final rawMoves = _chess.moves({'square': square, 'verbose': true});
      return rawMoves
          .map<String>((m) => (m as Map)['to'] as String)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  bool _isPieceOurs(chess_lib.Piece piece) {
    return (widget.isWhite && piece.color == chess_lib.Color.WHITE) ||
        (!widget.isWhite && piece.color == chess_lib.Color.BLACK);
  }

  // ── Tap handler ─────────────────────────────────────────────────────────────

  void _onTap(String algebraic) {
    if (!widget.isMyTurn) return;

    final piece = _chess.get(algebraic);

    if (_selectedSquare == null) {
      // Nothing selected — try to select our piece
      if (piece != null && _isPieceOurs(piece)) {
        setState(() {
          _selectedSquare = algebraic;
          _legalTargets = _legalMovesFrom(algebraic);
        });
      }
      return;
    }

    // Something already selected
    if (_selectedSquare == algebraic) {
      // Tap same square → deselect
      setState(() {
        _selectedSquare = null;
        _legalTargets = {};
      });
      return;
    }

    if (piece != null && _isPieceOurs(piece)) {
      // Tap another of our own pieces → change selection
      setState(() {
        _selectedSquare = algebraic;
        _legalTargets = _legalMovesFrom(algebraic);
      });
      return;
    }

    // Attempt a move (even if it's illegal — server will reject it)
    final from = _selectedSquare!;
    final to = algebraic;

    String? promotion;
    final movingPiece = _chess.get(from);
    if (movingPiece != null && movingPiece.type.name == 'p') {
      final toRank = int.parse(to[1]);
      if ((movingPiece.color == chess_lib.Color.WHITE && toRank == 8) ||
          (movingPiece.color == chess_lib.Color.BLACK && toRank == 1)) {
        promotion = 'q'; // Auto-promote to queen
      }
    }

    setState(() {
      _selectedSquare = null;
      _legalTargets = {};
      _lastMoveFrom = from;
      _lastMoveTo = to;
    });

    widget.onMove?.call(from, to, promotion: promotion);
  }

  // ── Square builder ───────────────────────────────────────────────────────────

  Widget _buildSquare(int file, int rank) {
    final sq = '${String.fromCharCode(97 + file)}${rank + 1}';
    final isLight = (file + rank) % 2 == 0;
    final piece = _chess.get(sq);
    final isSelected = _selectedSquare == sq;
    final isLegal = _legalTargets.contains(sq);
    final isLastMove = sq == _lastMoveFrom || sq == _lastMoveTo;
    final checkedKing = _findCheckedKingSquare();
    final isCheckedKing = sq == checkedKing;

    // ── Background colour ─────────────────────────────────────────────────────
    Color bg;
    if (isCheckedKing) {
      bg = isLight ? _checkLight : _checkDark;
    } else if (isSelected) {
      bg = isLight ? _selectedLight : _selectedDark;
    } else if (isLastMove) {
      bg = isLight ? _lastMoveLight : _lastMoveDark;
    } else {
      bg = isLight ? _lightSquare : _darkSquare;
    }

    return GestureDetector(
      onTap: () => _onTap(sq),
      child: Container(
        color: bg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Legal move indicator
            if (isLegal)
              piece == null
                  ? _buildDot()
                  : _buildCaptureRing(),
            // Piece
            if (piece != null)
              Center(child: _buildPiece(piece)),
          ],
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.32,
        heightFactor: 0.32,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.18),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureRing() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.black.withOpacity(0.25),
            width: 5,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _buildPiece(chess_lib.Piece piece) {
    final symbol = _pieceSymbol(piece);
    final isWhitePiece = piece.color == chess_lib.Color.WHITE;
    return Text(
      symbol,
      style: TextStyle(
        fontSize: 38,
        color: isWhitePiece ? Colors.white : const Color(0xFF1A1A1A),
        shadows: isWhitePiece
            ? const [
                Shadow(offset: Offset(-1.2, -1.2), color: Colors.black87, blurRadius: 0),
                Shadow(offset: Offset(1.2, -1.2), color: Colors.black87, blurRadius: 0),
                Shadow(offset: Offset(-1.2, 1.2), color: Colors.black87, blurRadius: 0),
                Shadow(offset: Offset(1.2, 1.2), color: Colors.black87, blurRadius: 0),
              ]
            : null,
      ),
    );
  }

  String _pieceSymbol(chess_lib.Piece piece) {
    const white = {'p': '♙', 'n': '♘', 'b': '♗', 'r': '♖', 'q': '♕', 'k': '♔'};
    const black = {'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛', 'k': '♚'};
    final map = piece.color == chess_lib.Color.WHITE ? white : black;
    return map[piece.type.name] ?? '';
  }

  // ── Main build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Rank labels: white sees 8→1 top-to-bottom; black sees 1→8
    // File labels: white sees a→h left-to-right; black sees h→a
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rank labels (left column)
              Column(
                children: List.generate(8, (i) {
                  final rank = widget.isWhite ? 8 - i : i + 1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              // Board
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Column(
                    children: List.generate(8, (rowIdx) {
                      // rowIdx 0 = top of display
                      final rank = widget.isWhite ? 7 - rowIdx : rowIdx;
                      return Expanded(
                        child: Row(
                          children: List.generate(8, (colIdx) {
                            final file = widget.isWhite ? colIdx : 7 - colIdx;
                            return Expanded(child: _buildSquare(file, rank));
                          }),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        // File labels (bottom row)
        Row(
          children: [
            const SizedBox(width: 20), // aligns with rank label column
            ...List.generate(8, (i) {
              final file = widget.isWhite
                  ? String.fromCharCode(97 + i)
                  : String.fromCharCode(104 - i);
              return Expanded(
                child: Center(
                  child: Text(
                    file,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}
