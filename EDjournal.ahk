#Warn, ClassOverwrite 
#Requires AutoHotKey v1.1.27+ ; Disable this line if you know what you're doing

class EDjournal
{

    class entry
    {
        eventName := ""
        callback := ""
    }
    
    static monitoredEvents := {}

    getLogFolderPath()
    {
        static journalPath
        if (journalPath == "")
        {
            EnvGet, journalPath, USERPROFILE
            journalPath .= "\Saved Games\Frontier Developments\Elite Dangerous\"
        }
        Return journalPath
    }

    getLogfileList(reverse := false)
    {
        static fileListOld          := "" ; the list of old naming pattern files is invariant so only needs to be done once 
        static fileListOldReversed  := "" ; same but in reverse order, trading RAM for speed

        ; on first call
        if (FileListOld == "")
        {
            Loop, Files, % this.getLogFolderPath() . "Journal.*.log"
            {
                ; move new naming convention log files into separate list
                if InStr(A_LoopFileName, "-")
                    FileListNew .= A_LoopFileName "`n"
                Else
                {
                    FileListOld         .= A_LoopFileName . "`n"
                    fileListOldReversed .= A_LoopFileName . "`n"
                }
            }
            Sort, fileListOld
            Sort, fileListOldReversed, R
        }
        Else
            Loop, Files, % this.getLogFolderPath() . "Journal.*-*.log"
                FileListNew .= A_LoopFileName "`n"

        ; sort lists alphabetically
        if reverse
        {
            Sort, FileListNew, R
            Return fileListNew . fileListOldReversed
        }
        Else
        {
            Sort, FileListNew
            Return fileListOld . fileListNew
        }
    }
}

Clipboard := EDjournal.getLogfileList()
MsgBox
Clipboard := EDjournal.getLogfileList(true)

/*
; get list of logs

carrierList := {}
events := { CarrierStats : {} , CarrierNameChange : {} , CarrierTradeOrder : {} }

result := runCMD("findstr ""\""event\"":\""Carrier"" """ . journalPath . "Journal*.log""")
Loop, Parse, result, `n
{
    logLines .= SubStr(A_LoopField, InStr(A_LoopField, "{")) . "`n"
}
Sort, logLines
result := "" ; free memory

SB_SetText("Processing Journal")
Loop, Parse, logLines, `n
{
    ; the game doesn't write a "CarrierBuy" event and "CarrierNameChange" doesn't trigger on buying either
    ; "CarrierStats" however gets written when accessing the FC management panel which is a prerequisite for pretty much anything
    ; so we're using this as a workaround for getting a carriers id, callsign, and initial name
    if InStr(A_LoopField, events.CarrierStats.needle.val)
    {
        id := extract(A_LoopField, "CarrierStats", "id")
        ; skip if FC is known already
        if carrierList.HasKey(id)
            Continue
        
        callsign := extract(A_LoopField, "CarrierStats", "callsign")
        name := extract(A_LoopField, "CarrierStats", "name")

        carrierList[id] := {"callsign" : callsign, "name" : name, "tradeOrders" : {}}
        Continue
    }

    ; tracking any subsequent name changes is similar to handling "CarrierStats"
    ; { "timestamp":"2020-06-18T16:00:13Z", "event":"CarrierNameChange", "CarrierID":3702178048, "Name":"HER MAJESTY'S EMBRACE", "Callsign":"Q6B-8KF" }
    if InStr(A_LoopField, events.CarrierNameChange.needle.val)
    {
        id := SubStr(A_LoopField, InStr(A_LoopField, events.CarrierNameChange.id.val) + events.CarrierNameChange.id.len, 10)

        carrierList[id].Name := extract(A_LoopField, "CarrierNameChange", "name")
    }

    ; { "timestamp":"2020-06-18T17:59:19Z", "event":"CarrierTradeOrder", "CarrierID":3702178048, "BlackMarket":false, "Commodity":"opal", "Commodity_Localised":"Void Opal", "PurchaseOrder":200, "Price":1000586 }
    ; { "timestamp":"2020-06-18T18:01:12Z", "event":"CarrierTradeOrder", "CarrierID":3702178048, "BlackMarket":false, "Commodity":"tritium", "PurchaseOrder":500, "Price":416840 }
    ; { "timestamp":"2020-11-12T16:14:24Z", "event":"CarrierTradeOrder", "CarrierID":3702178048, "BlackMarket":false, "Commodity":"buildingfabricators", "Commodity_Localised":"Building Fabricators", "CancelTrade":true}
    if InStr(A_LoopField, events.CarrierTradeOrder.needle.val)
    {
        ; determine which FC we're working with
        id := SubStr(A_LoopField, InStr(A_LoopField, events.CarrierTradeOrder.carrierID.val) + events.CarrierTradeOrder.carrierID.len, 10)

        ; get the game's internal commodity name
        commodity := extract(A_LoopField, "CarrierTradeOrder", "Commodity")
        ; show(commodity)

        ; a canceled order is least effort, remove and move on
        if InStr(A_LoopField, events.CarrierTradeOrder.cancel.val)
        {
            carrierList[id].tradeOrders.Delete(commodity)
            Continue
        }

        ; events.CarrierTradeOrder.Commodity_Localised
        name := extract(A_LoopField, "CarrierTradeOrder", "Commodity_Localised")
        if (name == "")
            StringUpper, name, commodity, T
        carrierList[id].tradeOrders[commodity].Name := name

        ; events.CarrierTradeOrder.BlackMarket
        StringUpper, bm, % extract(A_LoopField, "CarrierTradeOrder", "BlackMarket"), T

        type := "?"
        ; events.CarrierTradeOrder.buy
        if (extract(A_LoopField, "CarrierTradeOrder", "buy"))
            type := "Buy"
        
        ; events.CarrierTradeOrder.sell
        if (extract(A_LoopField, "CarrierTradeOrder", "sell"))
            type := "Sell"
        
        carrierList[id].tradeOrders[commodity] := {"Name" : name, "BlackMarket" : bm, "orderType" : type}
    }
}

insertIntoEvents(event, key, value, delimiter := ",")
{
    global events
    events[event][key] := {}
    events[event][key].val := value
    events[event][key].len := StrLen(value)
    events[event][key].del := delimiter
}

extract(source, event, key)
{
    global events
    offset := InStr(source, events[event][key].val)
    if (offset == 0)
    {
        ErrorLevel = 1
        Return ""
    }
    offset += events[event][key].len
    length := InStr(source, events[event][key].del, false, offset) - offset
    Return SubStr(source, offset, length)
}

runCMD(command := "") {
    static shell

    if (shell == "")
    {
        DetectHiddenWindows On
        Run %ComSpec%,, Hide, pid
        WinWait ahk_pid %pid%
        DllCall("AttachConsole", "UInt", pid)
        shell := ComObjCreate("WScript.Shell")
        OnExit(A_ThisFunc)
    }

    if (command == "")
    {
        objRelease(shell)
        DllCall( "FreeConsole" )
        Return
    }

    return shell.Exec(ComSpec " /C " command).StdOut.ReadAll()
}
