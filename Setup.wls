#!/usr/bin/env wolframscript

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

If[ $OperatingSystem =!= "Windows",
    Print[ "This script is only intended to run on Windows." ];
    Exit[ 1 ];
];

script = FileNameJoin @ {
    DirectoryName @ Replace[ $InputFileName, "" :> NotebookFileName[ ] ],
    "SlayTheSpireLLMController.wls"
};

If[ ! FileExistsQ @ script,
    Print @ StringForm[ "The script file \"`1`\" does not exist.", script ];
    Exit[ 1 ];
];

(* cSpell: ignore LOCALAPPDATA *)
configFile = FileNameJoin @ { Environment[ "LOCALAPPDATA" ], "ModTheSpire", "CommunicationMod", "config.properties" };

(* cSpell: ignore noinit *)
config = StringReplace[
    StringTemplate[ "command=`1` -noinit -runfirst Print[Ready] -script `2`\nrunAtGameStart=true" ][
        FileNameJoin @ { $InstallationDirectory, "wolfram.exe" },
        script
    ],
    { ":" -> "\\:", "\\" -> "\\\\" }
];

Print[ "Exporting config file: ", Export[ configFile, config, "String" ] ];

(* :!CodeAnalysis::EndBlock:: *)