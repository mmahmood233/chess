// custom_chess_board.dart — Interactive chess board widget.
//
// Renders an 8×8 board using SVG pieces from chess_vectors_flutter and
// validates legal moves client-side using the chess.dart library before
// forwarding taps to the parent via [onMove].
//
// Visual layers per square (bottom → top):
//   1. Base colour          — light (#F0D9B5) or dark (#B58863), Chess.com classic.
//   2. Last-move overlay    — semi-transparent olive on the from/to squares of
//                             the most recent move.
//   3. Selected overlay     — semi-transparent yellow on the tapped square.
//   4. Check overlay        — semi-transparent red on the checked king's square.
//   5. Legal-move indicator — small circle (empty square) or ring (capture square).
//   6. Piece                — SVG vector piece at 88 % of square size.
//   7. Coordinates          — rank numbers on the left column, file letters on
//                             the bottom row (Chess.com embedded style).
//
// Flip logic: when [isWhite] is false the board is rendered from black's
// perspective by reversing the file and rank iteration order.
import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';

// ── Board palette (Chess.com classic) ────────────────────────────────────────
const _lightSq = Color(0xFFF0D9B5);
const _darkSq  = Color(0xFFB58863);

// Semi-transparent overlays — keep the square colour visible underneath
const _selectedOverlay  = Color(0xBBF6F669); // 73 % yellow
const _lastMoveOverlay  = Color(0x88CDD26A); // 53 % olive-yellow
const _checkOverlay     = Color(0xDDFF4444); // 87 % red

/// Thin public wrapper that lets the parent pass a plain function reference
/// without needing to know about the internal stateful widget.
class CustomChessBoard extends StatelessWidget {
  /// Current board position in FEN notation.
  final String fen;

  /// Callback invoked when the player completes a legal move gesture.
  /// [from] and [to] are algebraic square names (e.g. "e2", "e4").
  /// [promotion] is set to 'q' when a pawn reaches the back rank.
  final Function(String from, String to, {String? promotion})? onMove;

  /// True if this client is playing white; false for black.
  final bool isWhite;

  /// Whether this client is currently allowed to make a move.
  final bool isMyTurn;

  /// Origin square of the last confirmed move (for highlight).
  final String? lastMoveFrom;

  /// Destination square of the last confirmed move (for highlight).
  final String? lastMoveTo;

  const CustomChessBoard({
    super.key,
    required this.fen,
    this.onMove,
    required this.isWhite,
    required this.isMyTurn,
    this.lastMoveFrom,
    this.lastMoveTo,
  });

  @override
  Widget build(BuildContext context) {
    return _ChessBoardWidget(
      fen: fen,
      onMove: onMove,
      isWhite: isWhite,
      isMyTurn: isMyTurn,
      lastMoveFrom: lastMoveFrom,
      lastMoveTo: lastMoveTo,
    );
  }
}

// ── Internal stateful board widget ───────────────────────────────────────────

class _ChessBoardWidget extends StatefulWidget {
  final String fen;
  final Function(String from, String to, {String? promotion})? onMove;
  final bool isWhite;
  final bool isMyTurn;
  final String? lastMoveFrom;
  final String? lastMoveTo;

  const _ChessBoardWidget({
    required this.fen,
    this.onMove,
    required this.isWhite,
    required this.isMyTurn,
    this.lastMoveFrom,
    this.lastMoveTo,
  });

  @override
  State<_ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<_ChessBoardWidget> {
  /// The currently selected square, or null if nothing is selected.
  String? _selectedSquare;

  /// Legal destination squares for the currently selected piece.
  Set<String> _legalTargets = {};

  /// chess.dart engine instance — loaded from FEN for client-side validation.
  late chess_lib.Chess _chess;

  @override
  void initState() {
    super.initState();
    _chess = chess_lib.Chess.fromFEN(widget.fen);
  }

  @override
  void didUpdateWidget(_ChessBoardWidget old) {
    super.didUpdateWidget(old);

    // FEN changed (move confirmed by server) — reload engine and clear selection
    if (old.fen != widget.fen) {
      _chess = chess_lib.Chess.fromFEN(widget.fen);
      setState(() {
        _selectedSquare = null;
        _legalTargets   = {};
      });
    }

    // Turn ended — clear any dangling selection
    if (old.isMyTurn && !widget.isMyTurn) {
      setState(() {
        _selectedSquare = null;
        _legalTargets   = {};
      });
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns the square of the king that is currently in check, or null.
  String? _checkedKingSquare() {
    if (!_chess.in_check) return null;
    final color = _chess.turn;
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sq = '${String.fromCharCode(97 + f)}${r + 1}';
        final p  = _chess.get(sq);
        if (p != null && p.type.name == 'k' && p.color == color) return sq;
      }
    }
    return null;
  }

  /// Returns the set of legal destination squares for the piece on [square].
  Set<String> _legalTargetsFor(String square) {
    try {
      return _chess
          .moves({'square': square, 'verbose': true})
          .map<String>((m) => (m as Map)['to'] as String)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// True if the piece at [p] belongs to this client.
  bool _isOurs(chess_lib.Piece p) =>
      (widget.isWhite && p.color == chess_lib.Color.WHITE) ||
      (!widget.isWhite && p.color == chess_lib.Color.BLACK);

  // ── Tap handler ─────────────────────────────────────────────────────────────

  /// Processes a tap on [sq].
  ///
  /// State machine:
  ///   • No selection + own piece tapped  → select it and show legal moves.
  ///   • Selection + same square tapped   → deselect.
  ///   • Selection + own piece tapped     → change selection to new piece.
  ///   • Selection + other square tapped  → attempt the move (auto-queen promo).
  void _onTap(String sq) {
    if (!widget.isMyTurn) return;
    final piece = _chess.get(sq);

    if (_selectedSquare == null) {
      if (piece != null && _isOurs(piece)) {
        setState(() {
          _selectedSquare = sq;
          _legalTargets   = _legalTargetsFor(sq);
        });
      }
      return;
    }

    // Tap the selected square again → deselect
    if (_selectedSquare == sq) {
      setState(() { _selectedSquare = null; _legalTargets = {}; });
      return;
    }

    // Tap a different own piece → change selection
    if (piece != null && _isOurs(piece)) {
      setState(() {
        _selectedSquare = sq;
        _legalTargets   = _legalTargetsFor(sq);
      });
      return;
    }

    // Attempt the move
    final from    = _selectedSquare!;
    String? promotion;
    final moving  = _chess.get(from);

    // Auto-promote pawns to queen (interactive promotion not yet implemented)
    if (moving != null && moving.type.name == 'p') {
      final toRank = int.parse(sq[1]);
      if ((moving.color == chess_lib.Color.WHITE && toRank == 8) ||
          (moving.color == chess_lib.Color.BLACK && toRank == 1)) {
        promotion = 'q';
      }
    }

    setState(() { _selectedSquare = null; _legalTargets = {}; });
    widget.onMove?.call(from, sq, promotion: promotion);
  }

  // ── Square builder ───────────────────────────────────────────────────────────

  /// Builds a single board square including all visual overlay layers.
  Widget _buildSquare(
    int file,
    int rank,
    String sq,
    double sqSize,
    String? checkedKing,
  ) {
    final isLight  = (file + rank) % 2 == 0;
    final piece    = _chess.get(sq);
    final selected = _selectedSquare == sq;
    final legal    = _legalTargets.contains(sq);
    final lastMove = sq == widget.lastMoveFrom || sq == widget.lastMoveTo;
    final inCheck  = sq == checkedKing;

    // Coordinate label visibility: rank numbers on left column, files on bottom row
    final isLeftCol   = widget.isWhite ? file == 0 : file == 7;
    final isBottomRow = widget.isWhite ? rank == 0 : rank == 7;
    final coordColor  = isLight ? _darkSq : _lightSq;
    final coordSize   = sqSize * 0.22;

    return GestureDetector(
      onTap: () => _onTap(sq),
      child: SizedBox(
        width: sqSize,
        height: sqSize,
        child: Stack(
          children: [
            // ── 1. Base square colour ───────────────────────────────────────
            Positioned.fill(
              child: ColoredBox(color: isLight ? _lightSq : _darkSq),
            ),

            // ── 2. Last-move highlight ──────────────────────────────────────
            if (lastMove && !selected && !inCheck)
              Positioned.fill(child: ColoredBox(color: _lastMoveOverlay)),

            // ── 3. Selected highlight ───────────────────────────────────────
            if (selected)
              Positioned.fill(child: ColoredBox(color: _selectedOverlay)),

            // ── 4. Check highlight ──────────────────────────────────────────
            if (inCheck)
              Positioned.fill(child: ColoredBox(color: _checkOverlay)),

            // ── 5a. Legal-move dot (empty target square) ────────────────────
            if (legal && piece == null)
              Center(
                child: Container(
                  width:  sqSize * 0.30,
                  height: sqSize * 0.30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.20),
                  ),
                ),
              ),

            // ── 5b. Legal-move ring (capture target square) ─────────────────
            if (legal && piece != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.28),
                      width: sqSize * 0.095,
                    ),
                    borderRadius: BorderRadius.circular(sqSize * 0.04),
                  ),
                ),
              ),

            // ── 6. Piece ────────────────────────────────────────────────────
            if (piece != null)
              Center(child: _buildPieceWidget(piece, sqSize * 0.88)),

            // ── 7a. Rank coordinate (left edge of left column) ───────────────
            if (isLeftCol)
              Positioned(
                top: 2,
                left: 3,
                child: Text(
                  '${rank + 1}',
                  style: TextStyle(
                    fontSize: coordSize,
                    fontWeight: FontWeight.bold,
                    color: coordColor,
                    height: 1,
                  ),
                ),
              ),

            // ── 7b. File coordinate (bottom edge of bottom row) ──────────────
            if (isBottomRow)
              Positioned(
                bottom: 2,
                right: 3,
                child: Text(
                  String.fromCharCode(97 + file), // 'a' … 'h'
                  style: TextStyle(
                    fontSize: coordSize,
                    fontWeight: FontWeight.bold,
                    color: coordColor,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── SVG piece builder ────────────────────────────────────────────────────────

  /// Returns the correct SVG piece widget for [piece] at the given [size].
  Widget _buildPieceWidget(chess_lib.Piece piece, double size) {
    final w = piece.color == chess_lib.Color.WHITE;
    switch (piece.type.name) {
      case 'k': return w ? WhiteKing(size: size)   : BlackKing(size: size);
      case 'q': return w ? WhiteQueen(size: size)  : BlackQueen(size: size);
      case 'r': return w ? WhiteRook(size: size)   : BlackRook(size: size);
      case 'b': return w ? WhiteBishop(size: size) : BlackBishop(size: size);
      case 'n': return w ? WhiteKnight(size: size) : BlackKnight(size: size);
      case 'p': return w ? WhitePawn(size: size)   : BlackPawn(size: size);
      default:  return const SizedBox.shrink();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sqSize = constraints.maxWidth / 8;
          final king   = _checkedKingSquare();

          // Generate 8 rows × 8 columns, respecting perspective flip
          return Column(
            children: List.generate(8, (rowIdx) {
              // White: rank 8 at top (rowIdx 0 → rank 7); Black: rank 1 at top
              final rank = widget.isWhite ? 7 - rowIdx : rowIdx;
              return Row(
                children: List.generate(8, (colIdx) {
                  // White: file a on left (colIdx 0 → file 0); Black: file h on left
                  final file = widget.isWhite ? colIdx : 7 - colIdx;
                  final sq   = '${String.fromCharCode(97 + file)}${rank + 1}';
                  return _buildSquare(file, rank, sq, sqSize, king);
                }),
              );
            }),
          );
        },
      ),
    );
  }
}
