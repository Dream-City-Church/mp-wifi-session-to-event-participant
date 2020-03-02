USE [MinistryPlatform]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[service_wifi_session_event_participant]

	@DomainID INT

AS

/****************************************
*** WiFi Session to Event Participant ***
*****************************************
A custom Dream City Church procedure for Ministry Platform
Version: 1.0
Author: Stephan Swinford
Date: 3/2/2020

This procedure is provided "as is" with no warranties expressed or implied.

-- Description --
This procedure creates Event Participant records for any Participant/Contact
with an associated WiFi Device and WiFi Session during an Event with the
Enable_WiFi_Attendence bitfield set to True.

https://github.com/Dream-City-Church/mp-wifi-session-to-event-participant

*****************************************
************ BEGIN PROCEDURE ************
****************************************/

INSERT INTO [dbo].[Event_Participants] (
    Event_ID,
    Participant_ID,
    Participation_Status_ID,
    Time_In,
    Time_Out,
    Notes,
    Domain_ID
    )
SELECT DISTINCT
    [Event_ID] = MAX(E.Event_ID),
    [Participant_ID] = P.Participant_ID,
    [Participation_Status_ID] = 3,
    [Time_In] = MAX(WDS.Session_Start),
    [Time_Out] = MAX(WDS.Session_End),
    [Notes] = 'Created from WiFi Session to Event Participant procedure.',
    [Domain_ID] = @DomainID
FROM dbo.Participants P
	LEFT JOIN Contacts C ON P.Contact_ID = C.Contact_ID
	LEFT JOIN Wifi_Devices WD ON WD.Contact_ID = C.Contact_ID
	LEFT JOIN Wifi_Device_Sessions WDS ON WDS.Wifi_Device_ID = WD.Wifi_Device_ID
	INNER JOIN Events E ON (WDS.Session_Start BETWEEN E.Event_Start_Date AND E.Event_End_Date) OR (WDS.Session_End BETWEEN E.Event_Start_Date AND E.Event_End_Date)
	LEFT JOIN Locations L ON E.Location_ID = L.Location_ID
	LEFT JOIN Congregations Con ON L.Congregation_ID = Con.Congregation_ID
WHERE E.Enable_Wifi_Attendance = 1
	AND LEFT(WDS.Wifi_Space,3) = Con.Abbreviation
	AND E.Event_Start_Date BETWEEN GetDate()-7 AND GetDate()
	AND NOT EXISTS(SELECT * FROM Event_Participants EP WHERE EP.Participation_Status_ID = 3 AND EP.Participant_ID = P.Participant_ID AND EP.Event_ID = E.Event_ID)
GROUP BY P.Participant_ID