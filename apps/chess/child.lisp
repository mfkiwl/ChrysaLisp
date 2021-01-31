;jit compile apps native functions
(import "sys/lisp.inc")
(jit "apps/chess/" "lisp.vp" '("piece_scans"))

;imports
(import "class/lisp.inc")
(import "apps/chess/app.inc")

;piece map accses
(defmacro piece-map (_ i)
	`(elem (find-rev ,i ,(elem 0 (eval _))) (elem 1 ,_)))

;description of a pieces check influence
(structure 'vector 0
	(byte 'dx 'dy 'len))

;description of a pieces movement and capture action
(structure 'move vector_size
	(byte 'flag))

;check test, array of pieces that must not be on this vectors from the king
(structure 'test 0
	(byte 'pieces 'vectors))

;control paramaters
(defq max_ply 10 max_chess_moves (/ 218 2) max_search_entries 10000)

;piece values, in centipawns
(defq king_value 100000 queen_value 900 rook_value 500 bishop_value 330
	knight_value 320 pawn_value 100 mate_value (* king_value 10) timeout_value (* mate_value 2))

;piece capture actions, per vector
(defq no_capture 0 may_capture 1 must_capture 2)

;map board square contents to piece type/color
(defq piece_type_map (list "PRNBKQprnbkq "
	(list black black black black black black white white white white white white empty)))

;piece move vectors and capture actions
(defq black_pawn_moves (list
		(array 0 1 0 no_capture) (array -1 1 1 must_capture) (array 1 1 1 must_capture))
	white_pawn_moves (list
		(array 0 -1 0 no_capture) (array -1 -1 1 must_capture) (array 1 -1 1 must_capture))
	rook_moves (list
		(array 0 -1 7 may_capture) (array -1 0 7 may_capture) (array 0 1 7 may_capture) (array 1 0 7 may_capture))
	bishop_moves (list
		(array -1 -1 7 may_capture) (array 1 1 7 may_capture) (array -1 1 7 may_capture) (array 1 -1 7 may_capture))
	knight_moves (list
		(array -2 1 1 may_capture) (array 2 -1 1 may_capture) (array 2 1 1 may_capture) (array -2 -1 1 may_capture)
		(array -1 -2 1 may_capture) (array -1 2 1 may_capture) (array 1 -2 1 may_capture) (array 1 2 1 may_capture))
	queen_moves (list
		(array 0 -1 7 may_capture) (array -1 0 7 may_capture) (array 0 1 7 may_capture) (array 1 0 7 may_capture)
		(array -1 -1 7 may_capture) (array 1 1 7 may_capture) (array -1 1 7 may_capture) (array 1 -1 7 may_capture))
	king_moves (list
		(array 0 -1 1 may_capture) (array -1 0 1 may_capture) (array 0 1 1 may_capture) (array 1 0 1 may_capture)
		(array -1 -1 1 may_capture) (array 1 1 1 may_capture) (array -1 1 1 may_capture) (array 1 -1 1 may_capture)))

;map piece to its movement possibilities
(defq moves_map (list "PpRrBbNnQqKk"
	(list black_pawn_moves white_pawn_moves rook_moves rook_moves bishop_moves bishop_moves
		knight_moves knight_moves queen_moves queen_moves king_moves king_moves)))

;piece check vectors, king is tested for being on these vectors for check tests
(defq black_pawn_vectors (list (array -1 1 1) (array 1 1 1))
	white_pawn_vectors (list (array -1 -1 1) (array 1 -1 1))
	bishop_vectors (list (array -1 -1 7) (array 1 1 7) (array -1 1 7) (array 1 -1 7))
	rook_vectors (list (array 0 -1 7) (array -1 0 7) (array 0 1 7) (array 1 0 7))
	knight_vectors (list (array -1 -2 1) (array -1 2 1) (array -2 -1 1) (array -2 1 1)
		(array 1 -2 1) (array 1 2 1) (array 2 -1 1) (array 2 1 1))
	queen_vectors (list (array -1 -1 7) (array 1 1 7) (array -1 1 7) (array 1 -1 7)
		(array 0 -1 7) (array -1 0 7) (array 0 1 7) (array 1 0 7))
	king_vectors (list (array -1 -1 1) (array 1 1 1) (array -1 1 1) (array 1 -1 1)
		(array 0 -1 1) (array -1 0 1) (array 0 1 1) (array 1 0 1)))

;check tests, piece types given can not be on the vectors given
(defq black_tests (list
		(list "qb" bishop_vectors) (list "qr" rook_vectors) (list "n" knight_vectors)
		(list "k" king_vectors) (list "p" black_pawn_vectors))
	white_tests (list
		(list "QB" bishop_vectors) (list "QR" rook_vectors) (list "N" knight_vectors)
		(list "K" king_vectors) (list "P" white_pawn_vectors)))

;pawn values for board evaluation
(defq white_pawn_eval_values (array
	0 0 0 0 0 0 0 0
	50 50 50 50 50 50 50 50
	10 10 20 30 30 20 10 10
	5 5 10 25 25 10 5 5
	0 0 0 20 20 0 0 0
	5 -5 -10 0 0 -10 -5 5
	5 10 10 -20 -20 10 10 5
	0 0 0 0 0 0 0 0 pawn_value)
	black_pawn_eval_values (array
	0 0 0 0 0 0 0 0
	5 10 10 -20 -20 10 10 5
	5 -5 -10 0 0 -10 -5 5
	0 0 0 20 20 0 0 0
	5 5 10 25 25 10 5 5
	10 10 20 30 30 20 10 10
	50 50 50 50 50 50 50 50
	0 0 0 0 0 0 0 0 pawn_value))

;knight values for board evaluation
(defq white_knight_eval_values (array
	-50 -40 -30 -30 -30 -30 -40 -50
	-40 -20 0 0 0 0 -20 -40
	-30 0 10 15 15 10 0 -30
	-30 5 15 20 20 15 5 -30
	-30 0 15 20 20 15 0 -30
	-30 5 10 15 15 10 5 -30
	-40 -20 0 5 5 0 -20 -40
	-50 -40 -30 -30 -30 -30 -40 -50 knight_value)
	black_knight_eval_values (array
	-50 -40 -30 -30 -30 -30 -40 -50
	-40 -20 0 5 5 0 -20 -40
	-30 5 10 15 15 10 5 -30
	-30 0 15 20 20 15 0 -30
	-30 5 15 20 20 15 5 -30
	-30 0 10 15 15 10 0 -30
	-40 -20 0 0 0 0 -20 -40
	-50 -40 -30 -30 -30 -30 -40 -50 knight_value))

;bishop values for board evaluation
(defq white_bishop_eval_values (array
	-20 -10 -10 -10 -10 -10 -10 -20
	-10 0 0 0 0 0 0 -10
	-10 0 5 10 10 5 0 -10
	-10 5 5 10 10 5 5 -10
	-10 0 10 10 10 10 0 -10
	-10 10 10 10 10 10 10 -10
	-10 5 0 0 0 0 5 -10
	-20 -10 -10 -10 -10 -10 -10 -20 bishop_value)
	black_bishop_eval_values (array
	-20 -10 -10 -10 -10 -10 -10 -20
	-10 5 0 0 0 0 5 -10
	-10 10 10 10 10 10 10 -10
	-10 0 10 10 10 10 0 -10
	-10 5 5 10 10 5 5 -10
	-10 0 5 10 10 5 0 -10
	-10 0 0 0 0 0 0 -10
	-20 -10 -10 -10 -10 -10 -10 -20 bishop_value))

;rook values for board evaluation
(defq white_rook_eval_values (array
	0 0 0 0 0 0 0 0
	5 10 10 10 10 10 10 5
	-5 0 0 0 0 0 0 -5
	-5 0 0 0 0 0 0 -5
	-5 0 0 0 0 0 0 -5
	-5 0 0 0 0 0 0 -5
	-5 0 0 0 0 0 0 -5
	0 0 0 5 5 0 0 0 rook_value)
	black_rook_eval_values (array
	0 0 0 5 5 0 0 0
	-5 0 0 0 0 0 0 -5
	-5 0 0 0 0 0 0 -5
	-5 0 0 0 0 0 0 -5
	-5 0 0 0 0 0 0 -5
	-5 0 0 0 0 0 0 -5
	5 10 10 10 10 10 10 5
	0 0 0 0 0 0 0 0 rook_value))

;queen values for board evaluation
(defq white_queen_eval_values (array
	-20 -10 -10 -5 -5 -10 -10 -20
	-10 0 0 0 0 0 0 -10
	-10 0 5 5 5 5 0 -10
	-5 0 5 5 5 5 0 -5
	0 0 5 5 5 5 0 -5
	-10 5 5 5 5 5 0 -10
	-10 0 5 0 0 0 0 -10
	-20 -10 -10 -5 -5 -10 -10 -20 queen_value)
	black_queen_eval_values (array
	-20 -10 -10 -5 -5 -10 -10 -20
	-10 0 5 0 0 0 0 -10
	-10 5 5 5 5 5 0 -10
	0 0 5 5 5 5 0 -5
	-5 0 5 5 5 5 0 -5
	-10 0 5 5 5 5 0 -10
	-10 0 0 0 0 0 0 -10
	-20 -10 -10 -5 -5 -10 -10 -20 queen_value))

;king values for board evaluation
(defq white_king_eval_values (array
	-30 -40 -40 -50 -50 -40 -40 -30
	-30 -40 -40 -50 -50 -40 -40 -30
	-30 -40 -40 -50 -50 -40 -40 -30
	-30 -40 -40 -50 -50 -40 -40 -30
	-20 -30 -30 -40 -40 -30 -30 -20
	-10 -20 -20 -20 -20 -20 -20 -10
	20 20 0 0 0 0 20 20
	20 30 10 0 0 10 30 20 king_value)
	black_king_eval_values (array
	20 30 10 0 0 10 30 20
	20 20 0 0 0 0 20 20
	-10 -20 -20 -20 -20 -20 -20 -10
	-20 -30 -30 -40 -40 -30 -30 -20
	-30 -40 -40 -50 -50 -40 -40 -30
	-30 -40 -40 -50 -50 -40 -40 -30
	-30 -40 -40 -50 -50 -40 -40 -30
	-30 -40 -40 -50 -50 -40 -40 -30 king_value))

;map piece to evaluation value table
(defq piece_evaluation_map (list "KQRBNPkqrbnp"
	(list black_king_eval_values black_queen_eval_values black_rook_eval_values
		black_bishop_eval_values black_knight_eval_values black_pawn_eval_values
		white_king_eval_values white_queen_eval_values white_rook_eval_values
		white_bishop_eval_values white_knight_eval_values white_pawn_eval_values)))

;generate all first hit pieces from index position along given vectors
(defun piece-scans (brd index vectors)
	(defq yield "" cx (logand index 7) cy (>> index 3))
	(each! 0 -1 (lambda ((dx dy len))
		(defq x cx y cy)
		(while (>= (setq len (dec len)) 0)
			(cond
				((and (<= 0 (setq x (+ x dx)) 7) (<= 0 (setq y (+ y dy)) 7))
					;still on the board
					(unless (eql (defq piece (elem (+ (* y 8) x) brd)) " ")
						;not empty square so yield piece
						(setq yield (cat yield piece) len 0)))
				(t	;off the edge
					(setq len 0))))) (list vectors)) yield)

;native versions
(ffi piece-scans "apps/chess/piece_scans" 0)

;test if king of given color is in check
(defun in-check (brd color)
	(if (= color (const black))
		(defq king_piece "K" tests (list black_tests))
		(defq king_piece "k" tests (list white_tests)))
	;find king index on board
	(defq king_index (find-rev king_piece brd))
		(some! 0 -1 nil (lambda ((pieces vectors))
			(defq hit_pieces (piece-scans brd king_index vectors) pieces (list pieces))
			(some! 0 -1 nil (lambda (piece)
				(find-rev piece hit_pieces)) pieces)) tests))

;evaluate (score) a board for the color given
(defun evaluate (brd color)
	(defq black_score 0 white_score 0)
	(each! 0 -1 (lambda (piece)
		;add score for position on the board, piece type, near center, clear lines etc
		(unless (eql piece " ")
			(defq eval_values (piece-map piece_evaluation_map piece))
			(if (> (code piece) (ascii-code "Z"))
				(setq white_score (+ white_score (elem 64 eval_values) (elem _ eval_values)))
				(setq black_score (+ black_score (elem 64 eval_values) (elem _ eval_values)))))) (list brd))
	(* (- white_score black_score) color))

;generate all boards for a piece index and moves possibility, filtering out boards where king is in check
(defun piece-moves (yield brd index color moves)
	(defq piece (elem index brd) cx (logand index 7) cy (>> index 3)
		promote (if (= color (const black)) '("QRBN") '("qrbn")))
	(each! 0 -1 (lambda ((dx dy len flag))
		(defq x cx y cy)
		;special length for pawns so we can adjust for starting 2 hop
		(when (= len 0)
			(setq len 1)
			(if (eql piece "P")
				(if (= y 1) (setq len 2))
				(if (= y 6) (setq len 2))))
		(while (>= (setq len (dec len)) 0)
			(cond
				((and (<= 0 (setq x (+ x dx)) 7) (<= 0 (setq y (+ y dy)) 7))
					(defq newindex (+ (* y 8) x) newpiece (elem newindex brd)
						newtype (piece-map piece_type_map newpiece))
					(cond
						((= newtype color)
							;hit one of our own piece type (black hit black etc)
							(setq len 0))
						((and (= flag (const no_capture)) (/= newtype (const empty)))
							;not suposed to capture and not empty square
							(setq len 0))
						((and (= flag (const must_capture)) (= newtype (const empty)))
							;must capture and got empty square
							(setq len 0))
						(t	;try this move
							(defq newbrd (cat (slice 0 index brd) " " (slice (inc index) -1 brd)))
							(cond
								((and (or (= y 0) (= y 7)) (or (eql piece "P") (eql piece "p")))
									;try all the pawn promotion possibilities
									(each! 0 -1 (lambda (promote_piece)
										(setq newbrd (cat (slice 0 newindex newbrd) promote_piece (slice (inc newindex) -1 newbrd)))
										(unless (in-check newbrd color)
											(push yield newbrd))) promote))
								(t	;generate this as a possible move
									(setq newbrd (cat (slice 0 newindex newbrd) piece (slice (inc newindex) -1 newbrd)))
									(unless (in-check newbrd color)
										(push yield newbrd))))
							(if (and (= flag (const may_capture)) (/= newtype (const empty)))
								;may capture and we did so !
								(setq len 0)))))
				(t	;gone off the board
					(setq len 0))))) (list moves)))

;generate all moves (boards) for the given colours turn
(defun all-moves (brd color)
	;enumarate the board square by square
	(task-sleep 0)
	(defq yield (list) is_black (= color (const black)))
	(each! 0 -1 (lambda (piece)
		(unless (eql piece " ")
			(when (eql (< (code piece) (ascii-code "Z")) is_black)
				;one of our pieces ! so gather all boards from possible moves of this piece
				(piece-moves yield brd _ color (piece-map moves_map piece))))) (list brd)) yield)

;pvs search
(defun pvs (brd color alpha beta ply)
	(cond
		((mail-poll select)
			timeout_value)
		((>= (- (pii-time) start_time) max_time_per_move)
			timeout_value)
		((= ply 0)
			(evaluate brd color))
		(t	(defq next_boards (all-moves brd color))
			(some! 0 -1 nil (lambda (brd)
				(cond
					((= _ 0)
						(defq value (neg (pvs brd (neg color) (neg beta) (neg alpha) (dec ply)))))
					(t	(defq value (neg (pvs brd (neg color) (dec (neg alpha)) (neg alpha) (dec ply))))
						(if (< alpha value beta)
							(setq value (neg (pvs brd (neg color) (neg beta) (neg value) (dec ply)))))))
				(>= (setq alpha (max alpha value)) beta)) (list next_boards))
			alpha)))

;negamax search
(defun negamax (brd color alpha beta ply)
	(cond
		((mail-poll select)
			timeout_value)
		((>= (- (pii-time) start_time) max_time_per_move)
			timeout_value)
		((= ply 0)
			(evaluate brd color))
		(t	(defq value +min_int+ next_boards (all-moves brd color))
			(some! 0 -1 nil (lambda (brd)
				(setq value (max value (neg (negamax brd (neg color) (neg beta) (neg alpha) (dec ply))))
					alpha (max alpha value))
				(>= alpha beta)) (list next_boards))
			value)))

(defun reply (data)
	;send msg to parent, sequenced
	(mail-send reply_mbox (cat (char next_seq (const long_size)) data))
	(setq next_seq (inc next_seq)))

;best move for given board position for given color
(defun best-move (brd color history)
	;start move time, sorted ply0 boards
	(defq start_time (pii-time) nbrd nil pbrd nil bias (list)
		ply0_boards (sort (lambda (a b) (- (elem 0 b) (elem 0 a)))
			(map (lambda (brd) (list (evaluate brd color) brd)) (all-moves brd color))))
	;bias against repeat positions
	(each! 0 -1 (lambda ((ply0_score brd))
		(push bias (* queen_value (reduce (lambda (cnt past_brd)
				(if (eql past_brd brd) (inc cnt) cnt)) history 0)))) (list ply0_boards))
	;iterative deepening of ply so we allways have a best move to go with if the time expires
	(some! 0 -1 nil (lambda (ply)
		(reply (str "s" (LF) "Ply" ply " "))
		(defq value +min_int+ alpha +min_int+ beta +max_int+
			timeout (some! 0 -1 nil (lambda ((ply0_score brd))
				(defq score (neg (negamax brd (neg color) (neg beta) (neg alpha) (dec ply))))
				(cond
					((or (<= (- score (elem _ bias)) value) (= (abs score) (const timeout_value)))
						(reply (cat "s" ".")))
					(t	(setq value score pbrd brd)
						(reply (cat "s" "*"))))
				(setq alpha (max alpha value))
				(cond
					((= (abs score) (const timeout_value))
						timeout_value)
					((>= alpha beta)))) (list ply0_boards)))
		(if (num? timeout) t
			(setq nbrd (if pbrd pbrd nbrd) pbrd nil))) (list (range 1 max_ply)))
	nbrd)

(structure '+select 0
	(byte 'main+ 'timeout+))

(defun main ()
	(defq select (list (task-mailbox) (mail-alloc-mbox)))
	(mail-timeout (elem +select_timeout+ select) 1000000)
	(defq msg (mail-read (elem (defq idx (mail-select select)) select)))
	(cond
		;timeout or quit
		((or (= idx +select_timeout+) (eql msg "")))
		;main mailbox, reset timeout and reply with move
		((= idx +select_main+)
			(mail-timeout (elem +select_timeout+ select) 0)
			;read job
			(defq reply_mbox (slice +job_reply+ (+ +job_reply+ net_id_size) msg)
				max_time_per_move (get-long msg +job_move_time+)
				color (get-byte msg +job_color+)
				brd (slice +job_board+ (+ +job_board+ 64) msg)
				history (list) history_offset (+ +job_board+ 64)
				next_seq 0)
			(while (< history_offset (length msg))
				(push history (slice history_offset (setq history_offset (+ history_offset 64)) msg)))
			;next move
			(defq new_brd (best-move brd color history))
			(cond
				((not new_brd)
					(if (in-check brd color)
						(reply (cat "e" (LF) "** Checkmate **" (LF)))
						(reply (cat "e" (LF) "** Stalemate **" (LF)))))
				((>= (reduce (lambda (cnt past_brd)
						(if (eql past_brd brd) (inc cnt) cnt)) history 0) 3)
					(reply (cat "e" (LF) "** Draw **" (LF))))
				(t	(reply (cat "b" new_brd))))))
	(mail-free-mbox (pop select)))
