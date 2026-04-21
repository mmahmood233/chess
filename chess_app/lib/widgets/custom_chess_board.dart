import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';

// ── Board palette (Chess.com classic) ────────────────────────────────────────
const _lightSq = Color(0xFFF0D9B5);
const _darkSq  = Color(0xFFB58863);

// Highlights — applied as a semi-transparent overlay so the base square colour
// still shows through, preventing the "solid block" look.
const _selectedOverlay  = Color(0xBBF6F669); // yellow
const _lastMoveOverlay  = Color(0x88CDD26A); // muted olive-yellow
const _checkOverlay     = Color(0xDDFF4444); // red for checked king

class CustomChessBoard extends StatelessWidget {
  final String fen;
  final Function(String from, String to, {String? promotion})? onMove;
  final bool isWhite;
  final bool isMyTurn;
  final String? lastMoveFrom;
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
  String? _selectedSquare;
  Set<String> _legalTargets = {};
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
    if (old.isMyTurn && !widget.isMyTurn) {
      setState(() {
        _selectedSquare = null;
        _legalTargets = {};
      });
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String? _checkedKingSquare() {
    if (!_chess.in_check) return null;
    final color = _chess.turn;
    for (var f = 0; f < 8; f++) {
      for (var r = 0; r < 8; r++) {
        final sq = '${String.fromCharCode(97 + f)}${r + 1}';
        final p = _chess.get(sq);
        if (p != null && p.type.name == 'k' && p.color == color) return sq;
      }
    }
    return null;
  }

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

  bool _isOurs(chess_lib.Piece p) =>
      (widget.isWhite && p.color == chess_lib.Color.WHITE) ||
      (!widget.isWhite && p.color == chess_lib.Color.BLACK);

  // ── Tap ─────────────────────────────────────────────────────────────────────

  void _onTap(String sq) {
    if (!widget.isMyTurn) return;
    final piece = _chess.get(sq);

    if (_selectedSquare == null) {
      if (piece != null && _isOurs(piece)) {
        setState(() {
          _selectedSquare = sq;
          _legalTargets = _legalTargetsFor(sq);
        });
      }
      return;
    }

    if (_selectedSquare == sq) {
      setState(() { _selectedSquare = null; _legalTargets = {}; });
      return;
    }

    if (piece != null && _isOurs(piece)) {
      setState(() {
        _selectedSquare = sq;
        _legalTargets = _legalTargetsFor(sq);
      });
      return;
    }

    // Attempt move
    final from = _selectedSquare!;
    String? promotion;
    final moving = _chess.get(from);
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

  Widget _buildSquare(
    int file,
    int rank,
    String sq,
    double sqSize,
    String? checkedKing,
  ) {
    final isLight   = (file + rank) % 2 == 0;
    final piece     = _chess.get(sq);
    final selected  = _selectedSquare == sq;
    final legal     = _legalTargets.contains(sq);
    final lastMove  = sq == widget.lastMoveFrom || sq == widget.lastMoveTo;
    final inCheck   = sq == checkedKing;

    // Coordinates: embedded Chess.com style
    // Rank numbers on the left-most display column; file letters on the bottom row.
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
            // ── Base square colour ──────────────────────────────────────────
            Positioned.fill(
              child: ColoredBox(color: isLight ? _lightSq : _darkSq),
            ),

            // ── Last-move highlight (overlay) ───────────────────────────────
            if (lastMove && !selected && !inCheck)
              Positioned.fill(child: ColoredBox(color: _lastMoveOverlay)),

            // ── Selected highlight (overlay) ────────────────────────────────
            if (selected)
              Positioned.fill(child: ColoredBox(color: _selectedOverlay)),

            // ── Check highlight (overlay) ────────────────────────────────────
            if (inCheck)
              Positioned.fill(child: ColoredBox(color: _checkOverlay)),

            // ── Legal move: dot (empty) ─────────────────────────────────────
            if (legal && piece == null)
              Center(
                child: Container(
                  width:  sqSize * 0.30,
                  height: sqSize * 0.30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.20),
                  ),
                ),
              ),

            // ── Legal move: ring (capture) ──────────────────────────────────
            if (legal && piece != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.black.withOpacity(0.28),
                      width: sqSize * 0.095,
                    ),
                    borderRadius: BorderRadius.circular(sqSize * 0.04),
                  ),
                ),
              ),

            // ── Piece ───────────────────────────────────────────────────────
            if (piece != null)
              Center(child: _buildPieceWidget(piece, sqSize * 0.88)),

            // ── Rank coordinate (left edge) ──────────────────────────────────
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

            // ── File coordinate (bottom edge) ────────────────────────────────
            if (isBottomRow)
              Positioned(
                bottom: 2,
                right: 3,
                child: Text(
                  String.fromCharCode(97 + file),
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

  // ── Vector piece builder ─────────────────────────────────────────────────────

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
          final king = _checkedKingSquare();
          return Column(
            children: List.generate(8, (rowIdx) {
              final rank = widget.isWhite ? 7 - rowIdx : rowIdx;
              return Row(
                children: List.generate(8, (colIdx) {
                  final file = widget.isWhite ? colIdx : 7 - colIdx;
                  final sq = '${String.fromCharCode(97 + file)}${rank + 1}';
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
