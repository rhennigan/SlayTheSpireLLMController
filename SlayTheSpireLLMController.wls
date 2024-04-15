#!/usr/bin/env wolframscript

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Print[ "Ready" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$logDirectory     = FileNameJoin @ { $UserBaseDirectory, "Logs", "SlayTheSpireLLMController" };
$logFile          = FileNameJoin @ { $logDirectory, "sts_log.wl" };
$model            = <| "Service" -> "OpenAI", "Name" -> "gpt-4-turbo" |>;
$disabledCommands = { "wait", "state", "click" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialize Files*)
If[ ! DirectoryQ @ $logDirectory, CreateDirectory @ $logDirectory ];

(* use ReadList to get data from this file, so Nothing initializes this to an empty list *)
Put[ Nothing, $logFile ];

(* monitor this file for any exceptions *)
Put[ None, FileNameJoin @ { $logDirectory, "sts_failure.wl" } ];

(* monitor this file to see LLM thoughts *)
Export[ FileNameJoin @ { $logDirectory, "sts_current.md" }, "", "String" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompting*)
$baseInstructions = "\
You are playing a game of Slay the Spire.\
You will be given JSON data that corresponds to the current game state, \
which you will use in order to choose a command to play.";

(* These usage messages are copied from the README for CommunicationMod.
   https://github.com/ForgottenArbiter/CommunicationMod/blob/master/README.md *)
$commandSyntax = <|
    "start"   -> "  - START PlayerClass [AscensionLevel] [Seed]\n    - Starts a new game with the selected class, on the selected Ascension level (default 0), with the selected seed (random seed if omitted).\n    - Seeds are alphanumeric, as displayed in game.\n    - This and all commands are case insensitive.\n    - Only currently available in the main menu of the game.\n",
    "potion"  -> "  - POTION Use|Discard PotionSlot [TargetIndex]\n    - Uses or discards the potion in the selected slot, on the selected target, if necessary.\n    - TargetIndex is the index of the target monster in the game's monster array (0-indexed).\n    - Only available when potions can be used or discarded.\n",
    "play"    -> "  - PLAY CardIndex [TargetIndex]\n    - Plays the selected card in your hand, with the selected target, if necessary.\n    - Only available when cards can be played in combat.\n    - Currently, CardIndex is 1-indexed to match up with the card numbers in game.\n  - END\n    - Ends your turn.\n    - Only available when the end turn button is available, in combat.\n",
    "end"     -> "  - END\n    - Ends your turn.\n    - Only available when the end turn button is available, in combat.\n",
    "choose"  -> "  - CHOOSE ChoiceIndex|ChoiceName\n    - Makes a choice relevant to the current screen.\n    - A list of names for each choice is provided in the game state. If provided with a name, the first choice index with the matching name is selected.\n    - Generally, available at any point when PLAY is not available.\n  - PROCEED\n    - Clicks the button on the right side of the screen, generally causing the game to proceed to a new screen.\n    - Equivalent to CONFIRM.\n    - Available whenever the proceed or confirm button is present on the right side of the screen.\n  - RETURN\n    - Clicks the button on the left side of the screen, generally causing you to return to the previous screen.\n    - Equivalent to SKIP, CANCEL, and LEAVE.\n    - Available whenever the return, cancel, or leave buttons are present on the left side of the screen. Also used for the skip button on card reward screens.\n",
    "proceed" -> "  - PROCEED\n    - Clicks the button on the right side of the screen, generally causing the game to proceed to a new screen.\n    - Equivalent to CONFIRM.\n    - Available whenever the proceed or confirm button is present on the right side of the screen.\n",
    "return"  -> "  - RETURN\n    - Clicks the button on the left side of the screen, generally causing you to return to the previous screen.\n    - Equivalent to SKIP, CANCEL, and LEAVE.\n    - Available whenever the return, cancel, or leave buttons are present on the left side of the screen. Also used for the skip button on card reward screens.\n",
    "key"     -> "  - KEY KeyName [Timeout]\n    - Presses the key corresponding to KeyName\n    - Possible key names are: Confirm, Cancel, Map, Deck, Draw_Pile, Discard_Pile, Exhaust_Pile, End_Turn, Up, Down, Left, Right, Drop_Card, Card_1, Card_2, ..., Card_10\n    - The actual keys pressed depend on the corresponding mapping in the game options\n    - If no state change is detected after [Timeout] frames (default 100), Communication Mod will then transmit the new state and accept input from the game. This is useful for key presses that open menus or pick up cards, without affecting the state as detected by Communication Mod.\n    - Only available in a run (not the main menus)\n",
    "click"   -> "  - CLICK Left|Right X Y\n    - Clicks the selected mouse button at the specified (X,Y) coordinates\n    - (0,0) is the upper left corner of the screen, and (1920,1080) is the lower right corner, regardless of game resolution\n    - Will move your cursor to the specified coordinates\n    - Timeout works the same as the CLICK command\n    - Only available in a run\n",
    "wait"    -> "  - WAIT Timeout\n    - Waits for the specified number of frames or until a state change is detected, then transmits the current game state (same behavior as Timeout for the CLICK and KEY commands, but no input is sent to the game)\n    - Possibly useful for KEY and CLICK commands which are expected to produce multiple state changes as detected by Communication Mod\n    - Only available in a run\n  - STATE\n    - Causes CommunicationMod to immediately send a JSON representation of the current state to the external process, whether or not the game state is stable.\n    - Always available.",
    "state"   -> "  - STATE\n    - Causes CommunicationMod to immediately send a JSON representation of the current state to the external process, whether or not the game state is stable.\n    - Always available.\n"
|>;

(* Aliases *)
$commandSyntax[ "skip"    ] = $commandSyntax[ "return"  ];
$commandSyntax[ "cancel"  ] = $commandSyntax[ "return"  ];
$commandSyntax[ "leave"   ] = $commandSyntax[ "return"  ];
$commandSyntax[ "confirm" ] = $commandSyntax[ "proceed" ];

$gameStateTemplate = StringTemplate[ "\
## Game State

`GameState`

## Command Syntax

`CommandSyntax`

Your task is to run one of the available commands.

You should first (very briefly) summarize the current state of the game, \
then think step-by-step about what command to play.

Pay attention to the incoming damage from enemies and your current block. \
If the total incoming damage exceeds your block, you will take damage.

Remember that cards are 1-indexed and monsters are 0-indexed.

Pay attention to which cards require a target. \
You MUST specify a target when playing these, even if there is only one possible target.

Then, when you've decided on an action, write out your chosen command in a code block (surround with three backticks).

Only write the command in the code block with no additional commentary. For example:
```
PLAY 2 1
```
" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*logFailure*)
logFailure[ args___ ] := (Put[ args, FileNameJoin @ { $logDirectory, "sts_failure.wl" }]);

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*echoLog*)
echoLog[ expr_ ] := (PutAppend[ expr, $logFile ]; expr);
echoLog[ expr_, label_ ] := (PutAppend[ label -> expr, $logFile ]; expr);

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getGameStateData*)
getGameStateData[ ] := getGameStateData @ InputString[ "" ];
getGameStateData[ input_String ] := getGameStateData[ input, Developer`ReadRawJSONString @ input ];

getGameStateData[ input_, state_Association ] := Enclose[
    Module[ { commands, commandSyntax },
        commands = ConfirmMatch[ state[ "available_commands" ], { __String }, "AvailableCommands" ];

        commandSyntax = ConfirmMatch[
            Lookup[ $commandSyntax, DeleteCases[ commands, Alternatives @@ $disabledCommands ] ],
            { __String },
            "CommandSyntax"
        ];

        $lastGameState = <|
            "GameState"     -> state,
            "CommandSyntax" -> StringRiffle[ commandSyntax, "\n" ]
        |>
    ],
    logFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateGameState*)
evaluateGameState[ ] := evaluateGameState @ getGameStateData[ ];

evaluateGameState[ as_Association ] /; $skipCount > 0 := ($skipCount--; Nothing);

evaluateGameState[ as_Association? waitQ ] := Nothing;

evaluateGameState[ as_Association ] := evaluateGameState[ as[ "GameState" ], as[ "CommandSyntax" ] ];

evaluateGameState[ KeyValuePattern[ "in_game" -> False ], _ ] := Nothing;

evaluateGameState[ state_Association, commandSyntax_String ] := Enclose[
    Module[ { jsonString, stateInstructions, chat, evaluated, message, response, commands, command },

        jsonString = ConfirmBy[ Developer`WriteRawJSONString @ state, StringQ, "JSONString" ];

        stateInstructions = TemplateApply[
            $gameStateTemplate,
            <| "GameState" -> jsonString, "CommandSyntax" -> commandSyntax |>
        ];

        chat = ConfirmMatch[
            ChatObject[ $baseInstructions, LLMEvaluator -> <| "Model" -> $model |> ],
            _ChatObject,
            "ChatObject"
        ];

        evaluated = ConfirmMatch[ ChatEvaluate[ chat, stateInstructions ], _ChatObject, "Evaluated" ];
        message   = ConfirmBy[ Last[ evaluated[ "Messages" ], $Failed ], AssociationQ, "Message" ];
        response  = ConfirmBy[ message[ "Content" ], StringQ, "Response" ];

        Export[ FileNameJoin @ { $logDirectory, "sts_current.md" }, response, "String" ];

        commands = ConfirmMatch[ parseGameCommands @ response, { __String }, "Commands" ];

        (* $skipCount = Length @ commands - 1; *)

        command = First[ commands, None ];

        If[ StringQ @ command, WriteLine[ "stdout", command ] ];

        echoLog @ <| "Commands" -> commands, "Response" -> response, "State" -> state |>
    ],
    logFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*waitQ*)
waitQ[ KeyValuePattern[ "GameState" -> state_ ] ] := waitQ @ state;
waitQ[ as_ ] := TrueQ @ waitingForInitialCardDrawQ @ as;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*waitingForInitialCardDrawQ*)
(* The first game state received during combat is before any cards are drawn, so the AI will think that ending its
   turn is the only available option. We use this to test if the game is currently in this state, and don't ask the
   LLM for a decision if so. *)
waitingForInitialCardDrawQ[ as_ ] := TrueQ @ And[
    as[ "game_state", "combat_state", "turn" ] === 1, (* it's the first turn... *)
    as[ "game_state", "combat_state", "hand" ] === { }, (* no cards have been drawn yet... *)
    as[ "game_state", "combat_state", "discard_pile" ] === { }, (* we know this because nothing is discarded... *)
    as[ "game_state", "combat_state", "exhaust_pile" ] === { } (* or exhausted. *)
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parseGameCommands*)
(* Extract the code block from the text generated by the LLM: *)
parseGameCommands[ s_String ] :=
    parseGameCommands @ StringCases[
        s,
        "```" ~~ Except[ "\n" ]... ~~ "\n" ~~ Shortest[ c__ ] ~~ "\n```" :> c
    ];


(*
    Sometimes the LLM tries to write commands as JSON, e.g.
    ```
    {
        "command": "PLAY 1 0"
    }
    ```
    It's simpler to just auto-correct this than to try to get the LLM to stop doing it. GPT-4 really loves JSON.
*)
parseGameCommands[ { block_String, ___ } ] :=
    With[ { json = Quiet @ Developer`ReadRawJSONString @ block },
        { json[ "command" ] } /; MatchQ[ json, KeyValuePattern[ "command" -> _String ] ]
    ];


(*
    Sometimes the LLM writes multiple commands, which *could* be made to work, but it's not supported yet.
    Currently, only the first one is used.
*)
parseGameCommands[ { block_String, ___ } ] :=
    StringSplit[ block, "\n" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)
$ProgressReporting = False;

While[ True, Block[ { PrintTemporary }, evaluateGameState[ ] ] ];

(* :!CodeAnalysis::EndBlock:: *)