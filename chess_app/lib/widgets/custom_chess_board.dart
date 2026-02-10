import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess_lib;

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
  int? _selectedSquare;
  late chess_lib.Chess _chess;

  @override
  void initState() {
    super.initState();
    _chess = chess_lib.Chess.fromFEN(widget.fen);
  }

  @override
  void didUpdateWidget(_ChessBoardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fen != widget.fen) {
      print('FEN updated: ${widget.fen}');
      _chess = chess_lib.Chess.fromFEN(widget.fen);
      _selectedSquare = null;
      
      // Debug: Print piece colors
      for (var i = 0; i < 64; i++) {
        final file = i % 8;
        final rank = 7 - (i ~/ 8);
        final algebraic = '${String.fromCharCode(97 + file)}${rank + 1}';
        final piece = _chess.get(algebraic);
        if (piece != null && piece.type.name == 'p') {
          print('Pawn at $algebraic: color=${piece.color.name}');
        }
      }
    }
  }

  void _onSquareTap(int square) {
    if (!widget.isMyTurn) return;

    final algebraic = _squareToAlgebraic(square);
    final piece = _chess.get(algebraic);

    if (_selectedSquare == null) {
      // Select piece
      if (piece != null && _isPieceOurs(piece)) {
        setState(() {
          _selectedSquare = square;
        });
      }
    } else {
      // Make move
      final from = _squareToAlgebraic(_selectedSquare!);
      final to = algebraic;
      
      // Check if this is a pawn promotion
      final movingPiece = _chess.get(_squareToAlgebraic(_selectedSquare!));
      String? promotion;
      
      if (movingPiece != null && movingPiece.type.name == 'p') {
        final toRank = int.parse(to[1]);
        // White pawn reaching rank 8 or black pawn reaching rank 1
        if ((movingPiece.color == chess_lib.Color.WHITE && toRank == 8) ||
            (movingPiece.color == chess_lib.Color.BLACK && toRank == 1)) {
          promotion = 'q'; // Auto-promote to queen
        }
      }

      setState(() {
        _selectedSquare = null;
      });

      if (widget.onMove != null) {
        widget.onMove!(from, to, promotion: promotion);
      }
    }
  }

  bool _isPieceOurs(chess_lib.Piece piece) {
    return (widget.isWhite && piece.color == chess_lib.Color.WHITE) ||
           (!widget.isWhite && piece.color == chess_lib.Color.BLACK);
  }

  String _squareToAlgebraic(int square) {
    final file = square % 8;
    final rank = 7 - (square ~/ 8);
    return '${String.fromCharCode(97 + file)}${rank + 1}';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: 64,
        itemBuilder: (context, index) {
          final displayIndex = widget.isWhite ? index : (63 - index);
          final file = displayIndex % 8;
          final rank = 7 - (displayIndex ~/ 8);
          final isLight = (file + rank) % 2 == 0;
          final algebraic = '${String.fromCharCode(97 + file)}${rank + 1}';
          final piece = _chess.get(algebraic);
          final isSelected = _selectedSquare == displayIndex;

          return GestureDetector(
            onTap: () => _onSquareTap(displayIndex),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.yellow.withOpacity(0.5)
                    : isLight
                        ? const Color(0xFFF0D9B5)
                        : const Color(0xFFB58863),
              ),
              child: Center(
                child: piece != null
                    ? Text(
                        _getPieceSymbol(piece),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..style = PaintingStyle.fill
                            ..color = piece.color == chess_lib.Color.WHITE
                                ? Colors.white
                                : Colors.black,
                          shadows: piece.color == chess_lib.Color.WHITE
                              ? [
                                  const Shadow(
                                    offset: Offset(0, 0),
                                    blurRadius: 3,
                                    color: Colors.black,
                                  ),
                                  const Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black,
                                  ),
                                  const Shadow(
                                    offset: Offset(-1, -1),
                                    blurRadius: 3,
                                    color: Colors.black,
                                  ),
                                  const Shadow(
                                    offset: Offset(1, -1),
                                    blurRadius: 3,
                                    color: Colors.black,
                                  ),
                                  const Shadow(
                                    offset: Offset(-1, 1),
                                    blurRadius: 3,
                                    color: Colors.black,
                                  ),
                                ]
                              : null,
                        ),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  String _getPieceSymbol(chess_lib.Piece piece) {
    // Use filled symbols for black, outlined for white
    if (piece.color == chess_lib.Color.WHITE) {
      const whiteSymbols = {
        'p': '♙',
        'n': '♘',
        'b': '♗',
        'r': '♖',
        'q': '♕',
        'k': '♔',
      };
      return whiteSymbols[piece.type.name] ?? '';
    } else {
      const blackSymbols = {
        'p': '♟',
        'n': '♞',
        'b': '♝',
        'r': '♜',
        'q': '♛',
        'k': '♚',
      };
      return blackSymbols[piece.type.name] ?? '';
    }
  }
}
