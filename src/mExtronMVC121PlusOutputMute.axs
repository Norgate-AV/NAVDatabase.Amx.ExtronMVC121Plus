MODULE_NAME='mExtronMVC121PlusOutputMute'	(
                                                dev vdvObject,
                                                dev vdvControl
                                            )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'

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

volatile long ltDrive[] = { 200 }

volatile char cAtt[NAV_MAX_CHARS]
volatile char cIndex[4][NAV_MAX_CHARS]

volatile _NAVVolume uVolume

volatile integer iIsInitialized

volatile integer iRegistered
volatile integer iRegisterReady
volatile integer iRegisterRequested

volatile integer iID

volatile integer iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

volatile char cObjectTag[MAX_OBJECT_TAGS][NAV_MAX_CHARS]

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
     NAVLog("'Command to ',NAVStringSurroundWith(NAVDeviceToString(vdvControl), '[', ']'),': [',cParam,']'")
    send_command vdvControl,"cParam"
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
    cObjectTag[1] = 'Amt'
    if (iID) { BuildCommand('REGISTER',cObjectTag[1]) }
    NAVLog("'EXTRON_MVC_REGISTER<',itoa(iID),'>'")
}

define_function Process() {
    stack_var char cTemp[NAV_MAX_BUFFER]
    iSemaphore = true
    while (length_array(cRxBuffer) && NAVContains(cRxBuffer,'>')) {
	cTemp = remove_string(cRxBuffer,"'>'",1)
	if (length_array(cTemp)) {
	    NAVLog("'Parsing String From ',NAVStringSurroundWith(NAVDeviceToString(vdvControl), '[', ']'),': [',cTemp,']'")
	    if (NAVContains(cRxBuffer, cTemp)) { cRxBuffer = "''" }
	    select {
		active (NAVStartsWith(cTemp,'REGISTER')): {
		    iID = atoi(NAVGetStringBetween(cTemp,'<','>'))
		    iRegisterRequested = true
		    if (iRegisterReady) {
			Register()
		    }

		    NAVLog("'EXTRON_MVC_REGISTER_REQUESTED<',itoa(iID),'>'")
		}
		active (NAVStartsWith(cTemp,'INIT')): {
		    iIsInitialized = false
		    GetInitialized()
		    NAVLog("'EXTRON_MVC_INIT_REQUESTED<',itoa(iID),'>'")
		}
		active (NAVStartsWith(cTemp,'RESPONSE_MSG')): {
		    //stack_var char cResponseRequestMess[NAV_MAX_BUFFER]
		    stack_var char cResponseMess[NAV_MAX_BUFFER]
		    //cResponseRequestMess = NAVGetStringBetween(cTemp,'<','|')
		    cResponseMess = NAVGetStringBetween(cTemp,'<','>')
		    //BuildCommand('RESPONSE_OK',cResponseRequestMess)
		    select {
			active (NAVContains(cResponseMess,cObjectTag[1])): {
			    //if (NAVContains(cResponseMess,'OK>')) {
				remove_string(cResponseMess,"cObjectTag[1]",1)
				NAVLog("'DMP_MVC_OUTPUT_MUTE_RESPONSE_MESSSAGE<',cResponseMess,'>'")
				uVolume.Mute.Actual = atoi(cResponseMess)

				NAVLog("'DMP_MVC_OUTPUT_MUTE_ACTUAL_MUTE<',itoa(uVolume.Mute.Actual),'>'")

				/*
				switch (cAtt) {
				    case 'MTRX': {
					/*
					switch (cIndex[2]) {
					    case 'I':
					    case 'M': {
						if (atoi(cIndex[1]) < 9) {

						}else {

						}
					    }
					    default: {

					    }
					}
					*/
					switch (cResponseMess) {
					    case '0': { uVolume.Mute.Actual = true }
					    case '1': { uVolume.Mute.Actual = false }
					    case '3': { uVolume.Mute.Actual = false }
					    case '4': { uVolume.Mute.Actual = false }
					    case '5': { uVolume.Mute.Actual = false }
					}
				    }
				    default: { uVolume.Mute.Actual = atoi(cResponseMess) }
				}
				*/
			   // }

			    if (!iIsInitialized) {
				iIsInitialized = true
				BuildCommand('INIT_DONE','')
				NAVLog("'EXTRON_MVC_INIT_DONE<',itoa(iID),'>'")
			    }
			}
		    }
		}
	    }
	}
    }

    iSemaphore = false
}

define_function GetInitialized() {
    BuildCommand('POLL_MSG',BuildString('Z','',''))
}

define_function Poll() {
    BuildCommand('POLL_MSG',BuildString('Z','',''))
}

define_function char[NAV_MAX_BUFFER] BuildString(char cAtt[], char cIndex1[], char cVal[]) {
    stack_var char cTemp[NAV_MAX_BUFFER]
    if (length_array(cAtt)) { cTemp = "cTemp,cAtt" }
    //if (length_array(cIndex1)) { cTemp = "cTemp,cIndex1" }
    //if (length_array(cVal)) { cTemp = "cTemp,'*',cVal" }

    return cTemp
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START
create_buffer vdvControl,cRxBuffer
iModuleEnabled = true
rebuild_event()
(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[vdvControl] {
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
	//send_command vdvControl,"'READY'"
    }
    command: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
	stack_var char cCmdParam[2][NAV_MAX_CHARS]
	if (iModuleEnabled) {
	     NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))
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
		case 'MUTE': {
		    switch (cCmdParam[1]) {
			case 'ON': { BuildCommand('COMMAND_MSG',BuildString('1Z','','')) }
			case 'OFF': { BuildCommand('COMMAND_MSG',BuildString('0Z','','')) }
			case 'TOGGLE': {
			    if (uVolume.Mute.Actual) {
				BuildCommand('COMMAND_MSG',BuildString('0Z','',''))
			    }else {
				BuildCommand('COMMAND_MSG',BuildString('1Z','',''))
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
		case VOL_MUTE: {
		    NAVLog("'DMP_MVC_OBJECT_MUTE_TOGGLE<',itoa(iID),'>'")
		    if (uVolume.Mute.Actual) {
			BuildCommand('COMMAND_MSG',BuildString('0Z','',''))
		    }else {
			BuildCommand('COMMAND_MSG',BuildString('1Z','',''))
		    }
		}
	    }
	}
    }
    off: {

    }
}


(***********************************************************)
(*            THE ACTUAL PROGRAM GOES BELOW                *)
(***********************************************************)
DEFINE_PROGRAM {
    if (iModuleEnabled) {
	//NAVLog("'DMP_STATE_OBJECT_MAIN_LINE<',itoa(iID),'>'")
	[vdvObject,VOL_MUTE_FB]	= (uVolume.Mute.Actual)
    }
}

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

