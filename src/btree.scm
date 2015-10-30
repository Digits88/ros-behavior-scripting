;
; btree.scm
;
; Behavior tree in the atomspace.
; Under construction.
;
; Run the main loop:
;    (run)
; Pause the main loop:
;    (halt)
;
; Unit testing:
; The various predicates below can be manually unit tested by manually
; adding and removing new visible faces, and then manually invoking the
; various rules. See faces.scm for utilities:
;
; Manually insert a face: (make-new-face id)
; Remove a face: (remove-face id)
; Etc.: (show-room-state) (show-interaction-state) (show-visible-faces)
;
; Unit test the new-arrival sequence:
; (make-new-face "42")
; (cog-evaluate! (DefinedPredicateNode "New arrival sequence"))
; (show-acked-faces)
; (show-room-state)
; (show-interaction-state)
; (cog-evaluate! (DefinedPredicateNode "Interact with people"))
;

(add-to-load-path "/usr/local/share/opencog/scm")

(use-modules (opencog) (opencog query) (opencog exec))
(use-modules (opencog atom-types))
(use-modules (opencog cogserver))
(start-cogserver "../scripts/opencog.conf")

; (system "echo \"py\\n\" | cat - atomic.py |netcat localhost 17020")
(system "echo \"py\\n\" | cat - atomic-dbg.py |netcat localhost 17020")

(load-from-path "utilities.scm")

; (display %load-path)
; (add-to-load-path "../src")
(load-from-path "faces.scm")
(load-from-path "behavior-cfg.scm")

(use-modules (opencog logger))
; (cog-logger-set-stdout #t)


; ------------------------------------------------------
; State variables

(define soma-state (AnchorNode "Soma State"))
(define soma-sleeping (ConceptNode "Sleeping"))

;; Assume Eva is sleeping at first
(StateLink soma-state soma-sleeping)

;; Currently, interaction-state will be linked to the face-id of
;; person with whom interaction is taking place. (current_face_target in owyl)
(define interaction-state (AnchorNode "Interaction State"))
(define no-interaction (ConceptNode "none"))

(StateLink interaction-state no-interaction)
(StateLink (SchemaNode "start-interaction-timestamp") (NumberNode 0))

; current_emotion_duration set to default_emotion_duration
; (StateLink (SchemaNode "current expression duration") (TimeNode 1.0)) ; in seconds
(StateLink (SchemaNode "current expression duration") (NumberNode 6.0)) ; in seconds

;; The "look at neutral position" face. Used to tell the eye/head
;; movemet subsystem to move to a neutral position.
(define neutral-face (ConceptNode "0"))

; --------------------------------------------------------
; temp scaffolding and junk.

(define (print-msg node) (display (cog-name node)) (newline) (stv 1 1))
(define (print-f-msg node) (display (cog-name node)) (newline) (stv 0 1))
(define (print-atom atom) (format #t "Triggered: ~a \n" atom) (stv 1 1))

; --------------------------------------------------------
; Emotional-state to expression mapping. For a given emotional state
; (for example, happy, bored, excited) this specifies a range of
; expressions to display for that emotional state, as well as the
; intensities and durations.  `emo-set` adds an expression to an
; emotional state, while `emo-map` is used to set parameters.
(define (emo-expr-set emo-state expression)
	(EvaluationLink
		(PredicateNode "Emotion-expression")
		(ListLink (ConceptNode emo-state) (ConceptNode expression))))

(define (emo-expr-map emo-state expression param value)
	(StateLink (ListLink
		(ConceptNode emo-state) (ConceptNode expression) (SchemaNode param))
		(NumberNode value)))

; Shorthand utility, takes probability, intensity min and max, duration min
; and max.
(define (emo-expr-spec emo-state expression prob int-min int-max dur-min dur-max)
	(emo-expr-set emo-state expression)
	(emo-expr-map emo-state expression "probability" prob)
	(emo-expr-map emo-state expression "intensity-min" int-min)
	(emo-expr-map emo-state expression "intensity-max" int-max)
	(emo-expr-map emo-state expression "duration-min" dur-min)
	(emo-expr-map emo-state expression "duration-max" dur-max))

; Translation of behavior.cfg line 9 ff
(emo-expr-spec "new-arrival" "surprised"  1.0 0.2 0.4 10 15)

(emo-expr-spec "frustrated" "sad"         0.4 0.6 0.8 5 15)
(emo-expr-spec "frustrated" "confused"    0.4 0.6 0.8 5 15)
(emo-expr-spec "frustrated" "recoil"      0.1 0.1 0.2 5 15)
(emo-expr-spec "frustrated" "surprised"   0.1 0.1 0.2 5 15)

(emo-expr-spec "positive" "happy"         0.4 0.6 0.8 10 15)
(emo-expr-spec "positive" "comprehending" 0.2 0.5 0.8 10 15)
(emo-expr-spec "positive" "engaged"       0.2 0.5 0.8 10 15)

(emo-expr-spec "bored"    "bored"         0.7 0.4 0.7 10 15)
(emo-expr-spec "bored"    "sad"           0.1 0.1 0.3 10 15)
(emo-expr-spec "bored"    "happy"         0.2 0.1 0.3 10 15)

; --------------------------------------------------------
; Emotional-state to gesture mapping. For a given emotional state
; (for example, happy, bored, excited) this specifies a range of
; gestures to display for that emotional state, as well as the
; intensities and durations.  `ges-set` adds a gesture to an
; emotional state, while `ges-map` is used to set parameters.
(define (emo-gest-set emo-state gesture)
	(EvaluationLink
		(PredicateNode "Emotion-gesture")
		(ListLink (ConceptNode emo-state) (ConceptNode gesture))))

(define (emo-gest-map emo-state gesture param value)
	(StateLink (ListLink
		(ConceptNode emo-state) (ConceptNode gesture) (SchemaNode param))
		(NumberNode value)))

; Shorthand utility, takes probability, intensity min and max, duration min
; and max, repeat min and max.
(define (emo-gest-spec emo-state gesture prob
		int-min int-max rep-min rep-max spd-min spd-max)
	(emo-gest-set emo-state gesture)
	(emo-gest-map emo-state gesture "probability" prob)
	(emo-gest-map emo-state gesture "intensity-min" int-min)
	(emo-gest-map emo-state gesture "intensity-max" int-max)
	(emo-gest-map emo-state gesture "repeat-min" rep-min)
	(emo-gest-map emo-state gesture "repeat-max" rep-max)
	(emo-gest-map emo-state gesture "speed-min" spd-min)
	(emo-gest-map emo-state gesture "speed-max" spd-max))

; Translation of behavior.cfg line 75 ff
(emo-gest-spec "positive" "nod-1"  0.1 0.6 0.9 1 1 0.5 0.8)
(emo-gest-spec "positive" "nod-2"  0.1 0.2 0.4 1 1 0.8 0.9)

(emo-gest-spec "bored"   "yawn-1"  0.01 0.6 0.9 1 1 1 1)

(emo-gest-spec "sleep"  "blink-sleepy"  1 0.7 1.0 1 1 1 1)

(emo-gest-spec "wake-up" "shake-2"  0.4 0.7 1.0 1 1 0.7 0.8)
(emo-gest-spec "wake-up" "shake-3"  0.3 0.6 1.0 1 1 0.7 0.8)
(emo-gest-spec "wake-up" "blink"    0.3 0.8 1.0 2 4 0.9 1.0)

; --------------------------------------------------------
; Given the name of a emotion, pick one of the allowed emotional
; expressions at random. Example usage:
;
;   (cog-execute!
;      (PutLink (DefinedSchemaNode "Pick random expression")
;         (ConceptNode "positive")))
;
; This will pick out one of the "positive" emotions (defined above).
;
; XXX TODO: currently, this selects with uniform weighting; instead,
; the selection should be based on the "probability" parameter.
(DefineLink
	(DefinedSchemaNode "Pick random expression")
	(LambdaLink
		(VariableNode "$emo")
		(RandomChoiceLink
			(GetLink
				(VariableNode "$expr")
				(EvaluationLink
					(PredicateNode "Emotion-expression")
					(ListLink (VariableNode "$emo") (VariableNode "$expr")))))))

; As above, but for gestures.
(DefineLink
	(DefinedSchemaNode "Pick random gesture")
	(LambdaLink
		(VariableNode "$emo")
		(RandomChoiceLink
			(GetLink
				(VariableNode "$expr")
				(EvaluationLink
					(PredicateNode "Emotion-gesture")
					(ListLink (VariableNode "$emo") (VariableNode "$expr")))))))

; Pick a random numeric value, lying in the range between min and max.
; The range min and max depends on an emotion-expression pair. For an
; example usage, see below.
(define (pick-value-in-range min-name max-name)
	(LambdaLink
		(VariableList (VariableNode "$emo") (VariableNode "$expr"))
		(RandomNumberLink
			(GetLink (VariableNode "$int-min")
				(StateLink (ListLink
					(VariableNode "$emo") (VariableNode "$expr")
					(SchemaNode min-name)) (VariableNode "$int-min")))
			(GetLink (VariableNode "$int-max")
				(StateLink (ListLink
					(VariableNode "$emo") (VariableNode "$expr")
					(SchemaNode max-name)) (VariableNode "$int-max")))
		)))

; Get a random intensity value forthe indicated emotion-expression.
; That is, given an emotion-expression pair, this wil look up the
; min and max allowed intensity levels, and return a random number
; betwee these min and max values.
;
; Example usage:
;    (cog-execute!
;        (PutLink (DefinedSchemaNode "get random intensity")
;            (ListLink (ConceptNode "positive") (ConceptNode "engaged"))))
; will return an intensity level for the positive-egaged expression.
(DefineLink
	(DefinedSchemaNode "get random intensity")
	(pick-value-in-range "intensity-min" "intensity-max"))

; Similar to above, but for duration. See explanation above.
(DefineLink
	(DefinedSchemaNode "get random duration")
	(pick-value-in-range "duration-min" "duration-max"))

(DefineLink
	(DefinedSchemaNode "get random repeat")
	(pick-value-in-range "repeat-min" "repeat-max"))

(DefineLink
	(DefinedSchemaNode "get random speed")
	(pick-value-in-range "speed-min" "speed-max"))

; Show a expression from a given emotional class. Sends the expression
; to ROS for display.  Sets a timestamp as well.  The intensity and
; duration of the expression is picked randomly from the parameters for
; the emotion-expression.
;
; Example usage:
;    (cog-evaluate!
;        (PutLink (DefinedPredicateNode "Show expression")
;           (ListLink (ConceptNode "positive") (ConceptNode "engaged"))))
;
(DefineLink
	(DefinedPredicateNode "Show expression")
	(LambdaLink
		(VariableList (VariableNode "$emo") (VariableNode "$expr"))
		(SequentialAndLink
			;; Record the time
			(TrueLink (DefinedSchemaNode "set timestamp"))
			;; Send it off to ROS to actually do it.
			(EvaluationLink (GroundedPredicateNode "py:do_emotion")
				(ListLink
					(VariableNode "$expr")
					(PutLink
						(DefinedSchemaNode "get random duration")
						(ListLink (VariableNode "$emo") (VariableNode "$expr")))
					(PutLink
						(DefinedSchemaNode "get random intensity")
						(ListLink (VariableNode "$emo") (VariableNode "$expr")))
			))
		)
	))

; Show a gesture for a given emotional class. Sends the gesture
; to ROS for display.  The intensity, repetition and speed of the
; gesture is picked randomly from the parameters for the emotion-gesture.
;
; Example usage:
;    (cog-evaluate!
;        (PutLink (DefinedPredicateNode "Show gesture")
;           (ListLink (ConceptNode "positive") (ConceptNode "nod-1"))))
;
(DefineLink
	(DefinedPredicateNode "Show gesture")
	(LambdaLink
		(VariableList (VariableNode "$emo") (VariableNode "$gest"))
		(SequentialAndLink
			;; Send it off to ROS to actually do it.
			(EvaluationLink (GroundedPredicateNode "py:do_gesture")
				(ListLink
					(VariableNode "$gest")
					(PutLink
						(DefinedSchemaNode "get random intensity")
						(ListLink (VariableNode "$emo") (VariableNode "$gest")))
					(PutLink
						(DefinedSchemaNode "get random repeat")
						(ListLink (VariableNode "$emo") (VariableNode "$gest")))
					(PutLink
						(DefinedSchemaNode "get random speed")
						(ListLink (VariableNode "$emo") (VariableNode "$gest")))
			))
		)
	))

;
; Pick an expression of the given, and send it to ROS for display.
; The expression is picked randomly from the class of expressions for
; the given emotion.  Likewise, the strength of display, and the
; duration are picked randomly.  The timestamp is recorded as well.
;
; Example usage:
;    (cog-evaluate!
;       (PutLink (DefinedPredicateNode "Show random expression")
;          (ConceptNode "positive")))
; will pick one of te "positive" emotions, and send it off.
;
;; line 305 -- pick_random_expression()
(DefineLink
	(DefinedPredicateNode "Show random expression")
	(LambdaLink
		(VariableNode "$emo")
		(PutLink
			(DefinedPredicateNode "Show expression")
			(ListLink
				(VariableNode "$emo")
				(PutLink
					(DefinedSchemaNode "Pick random expression")
					(VariableNode "$emo"))
			))
	))

;; Like the above, but for gestures
;; line 334 -- pick_random_gesture()
(DefineLink
	(DefinedPredicateNode "Show random gesture")
	(LambdaLink
		(VariableNode "$emo")
		(PutLink
			(DefinedPredicateNode "Show gesture")
			(ListLink
				(VariableNode "$emo")
				(PutLink
					(DefinedSchemaNode "Pick random gesture")
					(VariableNode "$emo"))
			))
	))

; --------------------------------------------------------
; Show facial expressions and gestures suitable for a given emotional
; state. These are radom selectors, picking some expression randomly
; from a meu of choices, ad displaying it.

;; Pick random expression, and display it.
(DefineLink
	(DefinedPredicateNode "Show positive expression")
	(PutLink (DefinedPredicateNode "Show random expression")
		(ConceptNode "positive")))

;; line 840 -- show_frustrated_expression()
(DefineLink
	(DefinedPredicateNode "Show frustrated expression")
	(PutLink (DefinedPredicateNode "Show random expression")
		(ConceptNode "frustrated")))

;; Pick random positive  gesture
(DefineLink
	(DefinedPredicateNode "Pick random positive gesture")
	(PutLink (DefinedPredicateNode "Show random gesture")
		(ConceptNode "positive")))

; ------------------------------------------------------
; TODO --
;
; grep for NumberNode below, and make these (more easily) configurable.
; ------------------------------------------------------

; Return true `fract` percent of the time, else return false.
(define (dice-roll fract)
	(define rrr (random:uniform))
	(cog-logger-info "rando: ~A" rrr)
	(if (> (string->number (cog-name fract)) rrr)
		(stv 1 1) (stv 0 1)))

; line 588 -- dice_roll("glance_new_face")
(DefineLink
	(DefinedPredicateNode "dice-roll: glance")
	(EvaluationLink
		(GroundedPredicateNode "scm: dice-roll")
		(ListLink (NumberNode "0.5"))))

; ------------------------------------------------------
; Basic utilities for working with newly-visible faces.

;; ------
;;
;; Return true if a new face has become visible.
;; A "new  face" is one tat is visible (in the atomspace) but
;; has not yet bee acked.
;; line 631, is_someone_arrived()
(DefineLink
	(DefinedPredicateNode "Did someone arrive?")
	(SatisfactionLink
		(AndLink
			; If someone is visible...
			(PresentLink (EvaluationLink (PredicateNode "visible face")
					(ListLink (VariableNode "$face-id"))))
			; but not yet acknowledged...
			(AbsentLink (EvaluationLink (PredicateNode "acked face")
					(ListLink (VariableNode "$face-id"))))
		)))

;; Return the set of newly-arrived faces.
(DefineLink
	(DefinedSchemaNode "New arrivals")
	(GetLink
		(AndLink
			; If someone is visible...
			(PresentLink (EvaluationLink (PredicateNode "visible face")
					(ListLink (VariableNode "$face-id"))))
			; but not yet acknowledged...
			(AbsentLink (EvaluationLink (PredicateNode "acked face")
					(ListLink (VariableNode "$face-id"))))
	)))

;; Return he person with whom we are currently interacting.
;; aka "current_face_target" in Owyl.
(DefineLink
	(DefinedSchemaNode "Current interaction target")
	(GetLink (StateLink interaction-state (VariableNode "$x"))))

;; Return true if some face has is no longer visible (has left the room)
;; We detect this by looking for "acked" faces tat are not also visible.
;; line 641, is_someone_left()
(DefineLink
	(DefinedPredicateNode "Did someone leave?")
	(SatisfactionLink
		(AndLink
			; If someone was previously acked...
			(PresentLink (EvaluationLink (PredicateNode "acked face")
					(ListLink (VariableNode "$face-id"))))
			; But is no loger visible...
			(AbsentLink (EvaluationLink (PredicateNode "visible face")
					(ListLink (VariableNode "$face-id"))))
		)))

;; Return list of recetly departed individuals
(DefineLink
	(DefinedSchemaNode "New departures")
	(GetLink
		(AndLink
			; If someone was previously acked...
			(PresentLink (EvaluationLink (PredicateNode "acked face")
					(ListLink (VariableNode "$face-id"))))
			; But is no loger visible...
			(AbsentLink (EvaluationLink (PredicateNode "visible face")
					(ListLink (VariableNode "$face-id"))))
	)))

;;
;; Was the the room empty, viz: Does the atomspace contains the link
;; (StateLink (AnchorNode "Room State") (ConceptNode "room empty"))?
;; Note that the room state is updated only when "Update room state"
;; is called, so faces may be visible, but the room marked as empty.
;; Think "level trigger" instead of "edge trigger".
;; line 665, were_no_people_in_the_scene
(DefineLink
	(DefinedPredicateNode "was room empty?")
	(EqualLink
		(SetLink room-empty)
		(GetLink (StateLink room-state (VariableNode "$x")))
	))

;; Is there someone present?  We check for acked faces.
;; The someone-arrived code converts newly-visible faces to acked faces.
;; line 683 is_face_target().
(DefineLink
	(DefinedPredicateNode "Detected face")
	(SatisfactionLink
		(PresentLink
			(EvaluationLink (PredicateNode "acked face")
					(ListLink (VariableNode "$face-id")))
		)))

;; Randomly select a face out of the crowd.
;; line 747 -- select_a_face_target() and also
;; line 752 -- select_a_glance_target()
(DefineLink
	(DefinedSchemaNode "Select random face")
	(RandomChoiceLink (GetLink
		(EvaluationLink (PredicateNode "acked face")
			(ListLink (VariableNode "$face-id")))
	)))

;; Update the room empty/full status; update the list of acknowledged
;; faces.
;; line 973 -- clear_new_face_target()
(DefineLink
	(DefinedPredicateNode "Update status")
	(SatisfactionLink
		(SequentialAndLink
			(DefinedPredicateNode "Update room state")
			(TrueLink (PutLink
					(EvaluationLink (PredicateNode "acked face")
							(ListLink (VariableNode "$face-id")))
					(DefinedSchemaNode "New arrivals")))
		)))

;; line 980 -- clear_lost_face_target()
(DefineLink
	(DefinedPredicateNode "Clear lost face")
	(TrueLink (PutLink
		(DeleteLink
			(EvaluationLink (PredicateNode "acked face")
				(ListLink (VariableNode "$face-id"))))
		(DefinedSchemaNode "New departures"))
	))
;; ------
;;
;; Return true if interacting with someone.
;; line 650, is_interacting_with_someone
;; (cog-evaluate! (DefinedPredicateNode "is interacting with someone?"))
(DefineLink
	(DefinedPredicateNode "is interacting with someone?")
	(NotLink (EqualLink
		(SetLink no-interaction)
		(GetLink (StateLink interaction-state (VariableNode "$x"))))
	))

;; Send ROS message to look at the person we are interacting with.
;; line 742, assign_face_target
(DefineLink
	(DefinedSchemaNode "look at person")
	(PutLink
		(EvaluationLink (GroundedPredicateNode "py:look_at_face")
			(ListLink (VariableNode "$face")))
		(GetLink (StateLink interaction-state (VariableNode "$x")))
	))

;; line 818, glance_at_new_face
(DefineLink
	(DefinedSchemaNode "glance at person")
	(PutLink
		(EvaluationLink (GroundedPredicateNode "py:glance_at_face")
			(ListLink (VariableNode "$face")))
		(DefinedSchemaNode "New arrivals")
	))

;; Move to a neutral head position. Right now, this just issues a
;; look-at command; it could do more (e.g. halt the chatbot.)
;; line 845, return_to_neutral_position
(DefineLink
	(DefinedPredicateNode "return to neutral")
	(SequentialAndLink
		(EvaluationLink (GroundedPredicateNode "py:look_at_face")
			(ListLink neutral-face))
	))

; ------------------------------------------------------
; Time-stamp-related stuff.

;; Set a timestamp. XXX todo replace this with timeserver.
;; line 757, timestamp
(DefineLink
	(DefinedSchemaNode "set timestamp")
	(PutLink
		(StateLink (SchemaNode "start-interaction-timestamp")
			(VariableNode "$x"))
		(TimeLink)))

(DefineLink
	(DefinedSchemaNode "get timestamp")
	(GetLink
		(StateLink (SchemaNode "start-interaction-timestamp")
			(VariableNode "$x"))))

;; Evaluate to true, if an expression should be shown.
;; line 933, should_show_expression()
(DefineLink
	(DefinedPredicateNode "Time to change expression")
	(GreaterThanLink
		(MinusLink
			(TimeLink)
			(DefinedSchemaNode "get timestamp"))
		(GetLink (StateLink (SchemaNode "current expression duration")
			(VariableNode "$x"))) ; in seconds
	))

; ------------------------------------------------------
; More complex interaction sequences.

;; Interact with the curent face target.
;; line 762, interact_with_face_target()
;; XXX Needs to be replaced by OpenPsi emotional state modelling.
;; XXX Almost a complete implementation of whats in owyl...  but
;; XXX The owyl pick_instant code is insane...
(DefineLink
	(DefinedPredicateNode "Interact with face")
	(SatisfactionLink
		(SequentialAndLink
			;; Look at the interaction face - line 765
			(TrueLink (PutLink
				(EvaluationLink (GroundedPredicateNode "py:look_at_face")
					(ListLink (VariableNode "$face")))
				(GetLink (StateLink interaction-state (VariableNode "$x")))))
			;; line 768
			(SequentialOrLink
				(NotLink (DefinedPredicateNode "Time to change expression"))
				(DefinedPredicateNode "Show positive expression")
			)
			(DefinedPredicateNode "Pick random positive gesture")
		)))

; ------------------------------------------------------
;; Sequence - if there were no people in the room, then look at the
;; new arrival.
;; line 391 -- owyl.sequence
;; (cog-evaluate! (DefinedPredicateNode "Was Empty Sequence"))
(DefineLink
	(DefinedPredicateNode "Was Empty Sequence")
	(SatisfactionLink
		(SequentialAndLink
			;; line 392
			(DefinedPredicateNode "was room empty?")
			(TrueLink (DefinedSchemaNode "interact with new person"))
			(TrueLink (DefinedSchemaNode "look at person"))
			(TrueLink (DefinedSchemaNode "set timestamp"))
			(EvaluationLink (GroundedPredicateNode "scm: print-msg")
				(ListLink (Node "--- Look at newly arrived person")))
		)))

(DefineLink
	(DefinedSchemaNode "interact with new person")
	(PutLink (StateLink interaction-state (VariableNode "$x"))
		(DefinedSchemaNode "New arrivals")))

;; line 399 -- Sequence - Currently interacting with someone
; (cog-evaluate! (DefinedPredicateNode "Interacting Sequence"))
(DefineLink
	(DefinedPredicateNode "Interacting Sequence")
	(SatisfactionLink
		(SequentialAndLink
			(DefinedPredicateNode "is interacting with someone?")
			(DefinedPredicateNode "dice-roll: glance")
			(TrueLink (DefinedSchemaNode "glance at person"))
			(EvaluationLink (GroundedPredicateNode "scm: print-msg")
				(ListLink (Node "--- Glance at person")))
	)))

;; Respond to a new face becoming visible.
;; line 389 -- Selector
(DefineLink
	(DefinedPredicateNode "Respond to new arrival")
	(SatisfactionLink
		(SequentialOrLink
			(DefinedPredicateNode "Was Empty Sequence")
			(DefinedPredicateNode "Interacting Sequence")
			(EvaluationLink (GroundedPredicateNode "scm: print-msg")
				(ListLink (Node "--- Ignoring new person"))) ; line 406
			(TrueLink)
		)))

;; Check to see if a new face has become visible.
;; line 386 -- someone_arrived()
(DefineLink
	(DefinedPredicateNode "New arrival sequence")
	(SatisfactionLink
		(SequentialAndLink
			(DefinedPredicateNode "Did someone arrive?")
			(DefinedPredicateNode "Respond to new arrival")
			(DefinedPredicateNode "Update status")
		)))

;; Check to see if someone left
;; line 422 -- someone_left()
;; XXX not implemented
(DefineLink
	(DefinedPredicateNode "Someone left")
	(SatisfactionLink
		(SequentialAndLink
			(DefinedPredicateNode "Did someone leave?")
			(EvaluationLink (GroundedPredicateNode "scm: print-msg")
				(ListLink (Node "--- Someone left")))
			(SequentialOrLink
				; Were we interacting with the person who left? If so,
				; look frustrated, return to neutral. Oh, and clear the
				; interaction target, too.
				(SequentialAndLink
					(EqualLink
						(DefinedSchemaNode "New departures")
						(GetLink (StateLink interaction-state (VariableNode "$x"))))
					(DefinedPredicateNode "Show frustrated expression")
					(DefinedPredicateNode "return to neutral")
					(TrueLink (PutLink
						(StateLink interaction-state (VariableNode "$face-id"))
						no-interaction))
				)
				;; Were we interacting with someone else?
				(SequentialAndLink
;xxxxxxxxxxxxxxxxxxxxx
					(FalseLink)
				)
				(EvaluationLink (GroundedPredicateNode "scm: print-msg")
					(ListLink (Node "--- Ignoring lost face")))
				(TrueLink)
			)
			;; Clear the lost face target
			(DefinedPredicateNode "Clear lost face")
		)))


;; Start a new interaction
;; line 461 -- sequence ....
; XXX  todo -- check if more than one face target
; record the start time ....
(DefineLink
	(DefinedPredicateNode "Start new interaction")
	(SatisfactionLink
		(SequentialAndLink
			(NotLink (DefinedPredicateNode "is interacting with someone?"))
			(TrueLink (PutLink
				(StateLink interaction-state (VariableNode "$face-id"))
					(DefinedSchemaNode "Select random face")))
		)))

;; Interact with people
;; line 457 -- interact_with_people()
(DefineLink
	(DefinedPredicateNode "Interact with people")
	(SatisfactionLink
		(SequentialAndLink
; XXX incomplete!
			(DefinedPredicateNode "Detected face")
			(TrueLink (DefinedSchemaNode "Select random face"))
			(DefinedPredicateNode "Interact with face")
		)))

;; Nothing is happening
;; line 507 -- nothing_is_happening()
;; XXX Not implemented!
(DefineLink
	(DefinedPredicateNode "Nothing is happening")
	(FalseLink)
)

;; ------------------------------------------------------------------
;; Main loop diagnostics
;; line 988 - idle_spin()
(define loop-count 0)
(define do-run-loop #t)
(define (idle-loop)
	(set! loop-count (+ loop-count 1))
	(format #t "Main loop: ~a\n" loop-count)
	(usleep 1001000)
	(if do-run-loop (stv 1 1) (stv 0 1)))

;; Main loop. Uses tail recursion optimizatio to form the loop.
;; line 556 -- build_tree()
(DefineLink
	(DefinedPredicateNode "main loop")
	(SatisfactionLink
		(SequentialAndLink
			(SequentialOrLink
				(DefinedPredicateNode "New arrival sequence")
				(DefinedPredicateNode "Someone left")
				(DefinedPredicateNode "Interact with people")
				(DefinedPredicateNode "Nothing is happening")
				(TrueLink)
			)
			(EvaluationLink
				(GroundedPredicateNode "scm:idle-loop") (ListLink))
			(EvaluationLink
				(GroundedPredicateNode "py:ros_is_running") (ListLink))
			(DefinedPredicateNode "main loop")
		)))

;; Run the loop (in a new thread)
;; Call (run) to run the loop, (halt) to pause the loop.
;; line 297 -- self.tree.next()
(define (run)
	(set! do-run-loop #t)
	(call-with-new-thread
		(lambda () (cog-evaluate! (DefinedPredicateNode "main loop")))))
(define (halt) (set! do-run-loop #f))
(all-threads)

;
; Silence the output.
(TrueLink)
