MODULE_NAME='mExtronMVC121PlusMixPointLevel'	(
                                                    dev vdvObject,
                                                    dev vdvCommObject
                                                )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.Math.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant long TL_DRIVE = 1

constant integer MAX_OBJECT_TAGS = 5

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE
volatile integer iModuleEnabled

volatile long ltDrive[] = { 500 }

volatile char cAtt[NAV_MAX_CHARS]
volatile char cIndex[4][NAV_MAX_CHARS]

volatile _NAVVolume uVolume

volatile sinteger siMaxLevel = 12
volatile sinteger siMinLevel = -24

volatile integer iIsInitialized

volatile integer iRegistered
volatile integer iRegisterReady
volatile integer iRegisterRequested

volatile integer iID
volatile char cObjectTag[MAX_OBJECT_TAGS][NAV_MAX_CHARS]

volatile integer iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function SendCommand(char cParam[]) {
     NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Command to ',NAVStringSurroundWith(NAVDeviceToString(vdvCommObject), '[', ']'),': [',cParam,']'")
    send_command vdvCommObject,"cParam"
}

define_function BuildCommand(char cHeader[], char cCmd[]) {
    if (length_array(cCmd)) {
	SendCommand("cHeader,'-<',itoa(iID),'|',cCmd,'>'")
    }else {
	SendCommand("cHeader,'-<',itoa(iID),'>'")
    }
}

define_function Register() {
    iRegistered = true
    cObjectTag[1] = "'In',cIndex[1],' Aud'"
    if (iID) { BuildCommand('REGISTER',"cObjectTag[1],'*',cObjectTag[2]") }
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'EXTRON_MVC_REGISTER<',itoa(iID),'>'")
}

define_function Process() {
    stack_var char cTemp[NAV_MAX_BUFFER]
    iSemaphore = true
    while (length_array(cRxBuffer) && NAVContains(cRxBuffer,'>')) {
	cTemp = remove_string(cRxBuffer,"'>'",1)
	if (length_array(cTemp)) {
	    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Parsing String From ',NAVStringSurroundWith(NAVDeviceToString(vdvCommObject), '[', ']'),': [',cTemp,']'")
	    if (NAVContains(cRxBuffer, cTemp)) { cRxBuffer = "''" }
	    select {
		active (NAVStartsWith(cTemp,'REGISTER')): {
		    iID = atoi(NAVGetStringBetween(cTemp,'<','>'))
		    iRegisterRequested = true
		    if (iRegisterReady) {
			Register()
		    }

		    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'EXTRON_MVC_REGISTER_REQUESTED<',itoa(iID),'>'")
		}
		active (NAVStartsWith(cTemp,'INIT')): {
		    //NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Request to Init'")
		    iIsInitialized = false
		    GetInitialized()
		    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'EXTRON_MVC_INIT_REQUESTED<',itoa(iID),'>'")
		}
		active (NAVStartsWith(cTemp,'RESPONSE_MSG')): {
		    //stack_var char cResponseRequestMess[NAV_MAX_BUFFER]
		    stack_var char cResponseMess[NAV_MAX_BUFFER]
		    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Response message: ',cTemp")
		    //cResponseRequestMess = NAVGetStringBetween(cTemp,'<','|')
		    cResponseMess = NAVGetStringBetween(cTemp,'<','>')
		    //BuildCommand('RESPONSE_OK',cResponseRequestMess)
		    select {
			active (NAVContains(cResponseMess,cObjectTag[1])): {
			    //if (NAVContains(cResponseMess,'OK>')) {
				remove_string(cResponseMess,"cObjectTag[1]",1)
				uVolume.Level.Actual = atoi(cResponseMess)
				send_level vdvObject,1,NAVScaleValue((uVolume.Level.Actual - siMinLevel),(siMaxLevel - siMinLevel),255,0)
			    //}

			    if (!iIsInitialized) {
				iIsInitialized = true
				BuildCommand('INIT_DONE','')
				NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'EXTRON_MVC_INIT_DONE<',itoa(iID),'>'")
			    }
			}
			/*
			active (NAVContains(cResponseMess,cObjectTag[2])): {
			    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'EXTRON_DMP_FOUND_SOFT_LIMIT_RESPONSE<',itoa(iID),'>'")
			    //if (NAVContains(cResponseMess,'OK>')) {
				remove_string(cResponseMess,"cObjectTag[2],'*'",1)
				siMaxLevel = atoi(NAVStripCharsFromRight(remove_string(cResponseMess,'*',1),1))
				NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'EXTRON_DMP_MAX_LEVEL<',itoa(siMaxLevel),'>'")
				siMinLevel = atoi(cResponseMess)
				NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'EXTRON_DMP_MIN_LEVEL<',itoa(siMinLevel),'>'")
				send_level vdvObject,1,NAVScaleValue((uVolume.Level.Actual - siMinLevel),(siMaxLevel - siMinLevel),255,0)
			    //}
			}
			*/
		    }
		}
	    }
	}
    }

    iSemaphore = false
}

define_function GetInitialized() {
    BuildCommand('POLL_MSG',BuildString(cIndex[1],'G',''))
}

define_function Poll() {
    BuildCommand('POLL_MSG',BuildString(cIndex[1],'G',''))
}

define_function char[NAV_MAX_BUFFER] BuildString(char cAtt[], char cIndex1[], char cVal[]) {
    stack_var char cTemp[NAV_MAX_BUFFER]
    if (length_array(cAtt)) { cTemp = "cTemp,cAtt" }
    if (length_array(cIndex1)) { cTemp = "cTemp,cIndex1" }
    //if (length_array(cVal)) { cTemp = "cTemp,'*',cVal" }

    return cTemp
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START
create_buffer vdvCommObject,cRxBuffer
iModuleEnabled = true
rebuild_event()
(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[vdvCommObject] {
    string: {
	if (iModuleEnabled) {
	    if (!iSemaphore) {
		Process()
	    }
	}
    }
}

data_event[vdvObject] {
    online: {
	//send_command vdvObject,"'READY'"
    }
    command: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
	stack_var char cCmdParam[2][NAV_MAX_CHARS]
	if (iModuleEnabled) {
	     NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Command from ',NAVStringSurroundWith(NAVDeviceToString(data.device), '[', ']'),': [',data.text,']'")
	    cCmdHeader = DuetParseCmdHeader(data.text)
	    cCmdParam[1] = DuetParseCmdParam(data.text)
	    cCmdParam[2] = DuetParseCmdParam(data.text)
	    switch (cCmdHeader) {
		case 'PROPERTY': {
		    switch (cCmdParam[1]) {
			/*
			case 'UNIT_TYPE': {
			    cUnitType = cCmdParam[2]
			}
			case 'UNIT_ID': {
			    cUnitID = cCmdParam[2]
			}
			*/
			case 'ATTRIBUTE': {
			    cAtt = cCmdParam[2]
			}
			case 'INDEX_1': {
			    cIndex[1] = cCmdParam[2]
			}
			case 'INDEX_2': {
			    cIndex[2] = cCmdParam[2]
			}
			case 'INDEX_3': {
			    cIndex[3] = cCmdParam[2]
			}
			case 'INDEX_4': {
			    cIndex[4] = cCmdParam[2]
			}
			case 'MAX_LEVEL': {
			    if (length_array(cCmdParam[2])) {
				siMaxLevel = atoi(cCmdParam[2])
			    }
			}
			case 'MIN_LEVEL': {
			    if (length_array(cCmdParam[2])) {
				siMinLevel = atoi(cCmdParam[2])
			    }
			}
		    }
		}
		case 'REGISTER': {
		    iRegisterReady = true
		    if (iRegisterRequested) {
			Register()
		    }
		}
		case 'INIT': {
		    GetInitialized()
		}
		case 'VOLUME': {
		    switch (cCmdParam[1]) {
			case 'QUARTER': {
			    if (iIsInitialized) {
				BuildCommand('COMMAND_MSG',BuildString("cIndex[1],'*',format('%d',NAVQuarterPointOfRange(siMaxLevel, siMinLevel)),'G'",'',''))
			    }
			}
			case 'HALF': {
			    if (iIsInitialized) {
				BuildCommand('COMMAND_MSG',BuildString("cIndex[1],'*',format('%d',NAVHalfPointOfRange(siMaxLevel, siMinLevel)),'G'",'',''))
			    }
			}
			case 'THREE_QUARTERS': {
			    if (iIsInitialized) {
				BuildCommand('COMMAND_MSG',BuildString("cIndex[1],'*',format('%d',NAVThreeQuarterPointOfRange(siMaxLevel, siMinLevel)),'G'",'',''))
			    }
			}
			case 'FULL': {
			    if (iIsInitialized) {
				BuildCommand('COMMAND_MSG',BuildString("cIndex[1],'*',format('%d',siMaxLevel),'G'",'',''))
			    }
			}
			case 'INC': {
			    if (uVolume.Level.Actual < siMaxLevel && iIsInitialized) {
				BuildCommand('COMMAND_MSG',BuildString(cIndex[1],'+G',''))
			    }
			}
			case 'DEC': {
			    if (uVolume.Level.Actual > siMinLevel && iIsInitialized) {
				BuildCommand('COMMAND_MSG',BuildString(cIndex[1],'-G',''))
			    }
			}
			case 'ABS': {
			    if ((atoi(cCmdParam[2]) >= siMinLevel) && (atoi(cCmdParam[2]) <= siMaxLevel) && iIsInitialized) {
				BuildCommand('COMMAND_MSG',BuildString("cIndex[1],'*',cCmdParam[2],'G'",'',''))
			    }
			}
			default: {
			    stack_var sinteger siLevel
			    siLevel = NAVScaleValue(atoi(cCmdParam[1]),255,(siMaxLevel - siMinLevel),siMinLevel)
			    if ((siLevel >= siMinLevel) && (siLevel <= siMaxLevel) && iIsInitialized) {
				BuildCommand('COMMAND_MSG',BuildString("cIndex[1],'*',format('%d',siLevel),'G'",'',''))
			    }
			}
		    }
		}
	    }
	}
    }
}

define_event channel_event[vdvObject,0] {
    on: {
	if (iModuleEnabled) {
	    switch (channel.channel) {
		case VOL_UP: {
		    if (iIsInitialized) {
			NAVTimelineStart(TL_DRIVE,ltDrive,TIMELINE_ABSOLUTE,TIMELINE_REPEAT)
		    }
		}
		case VOL_DN: {
		    if (iIsInitialized) {
			NAVTimelineStart(TL_DRIVE,ltDrive,TIMELINE_ABSOLUTE,TIMELINE_REPEAT)
		    }
		}
	    }
	}
    }
    off: {
	if (iModuleEnabled) {
	    NAVTimelineStop(TL_DRIVE)
	}
    }
}

timeline_event[TL_DRIVE] {
    select {
	active ([vdvObject,VOL_UP]): {
	    if (uVolume.Level.Actual < siMaxLevel && iIsInitialized) {
		BuildCommand('COMMAND_MSG',BuildString(cIndex[1],'+G',''))
	    }
	}
	active ([vdvObject,VOL_DN]): {
	    if (uVolume.Level.Actual > siMinLevel && iIsInitialized) {
		BuildCommand('COMMAND_MSG',BuildString(cIndex[1],'-G',''))
	    }
	}
    }
}

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

