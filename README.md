# SlayTheSpireLLMController

This is a basic Wolfram Language implementation of an LLM-based AI that plays [Slay the Spire](https://store.steampowered.com/app/646570/Slay_the_Spire/).

Here is a demo of it in action:

[![GPT-4 Plays Slay the Spire](https://i.ytimg.com/vi/vbb3mkSFS8k/hqdefault.jpg)](https://youtu.be/vbb3mkSFS8k "GPT-4 Plays Slay the Spire")

## Setup

> These instructions are specific to Windows and a copy of Slay the Spire purchased through Steam. Other platforms should work, but you're on your own for setup.

The following StS mods are required, which are available from the Steam Workshop:

* [CommunicationMod](https://steamcommunity.com/sharedfiles/filedetails/?id=2131373661)
* [ModTheSpire](https://steamcommunity.com/sharedfiles/filedetails/?id=1605060445)
* [BaseMod](https://steamcommunity.com/sharedfiles/filedetails/?id=1605833019)

Once you've installed the necessary mods, run the [Setup.wls](Setup.wls) script that's included with this repository, which will automatically create a config file for CommunicationMod:
```
wolframscript -f Setup.wls
```

Note: For this script to work, you need [SlayTheSpireLLMController.wls](SlayTheSpireLLMController.wls) to be contained in the same directory.

Next, launch the game from Steam using the "Play With Mods" option.

You'll see a ModTheSpire dialog that allows you to select which mods to enable. Make sure "BaseMod" and "CommunicationMod" are selected with everything else disabled, then click the "Play" button.

Start a game normally, then let the AI take it from there.

## Monitoring

To see dynamic output from the LLM like in the video above, you can evaluate the following in a notebook:
```wl
Needs[ "Wolfram`Chatbook`" ];
Dynamic @ Refresh[
    Style[
        FormatChatOutput @ Import[ 
            FileNameJoin @ { $UserBaseDirectory, "Logs", "SlayTheSpireLLMController", "sts_current.md" }, 
            "String" 
        ],
        "Text"
    ],
    UpdateInterval -> 1
]
```

## Known Issues

Screens where you need to select a card are not currently working. You'll need to choose one manually to proceed.

If the LLM issues an invalid command, the CommunicationMod will send back an error message, but I haven't hooked up any error handling here, so it gets ignored. At this point you'll need to manually do something in game to proceed to a new game state.

I made this in a couple hours with minimal testing. There's probably tons of other stuff that doesn't work either.