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
Version: 1.1
Author: Stephan Swinford
Date: 11/19/2020

This procedure is provided "as is" with no warranties expressed or implied.

-- Description --
This procedure creates Event Participant records for any Participant/Contact
with an associated WiFi Device and WiFi Session from FrontPorch during an Event 
with the Enable_WiFi_Attendance bitfield set to True. Currently, it will add
every Wi-Fi user at the campus during the event (working on ways to scope to
smaller areas based on FrontPorch zones).

There are 3 requirements for this procedure:

    - FrontPorch integration with Ministry Platform

    - 'Enable_WiFi_Attendance' Bit column added to the Events table

    - 'Abbrevation' VarChar(50) column added to the Congregations table

        *** Internally, we use abbrevations when referring to our campuses
        in order to save space (e.g. "PHX" for "Phoenix Campus"). We originally
        added the Abbreviations column to make Selected Record Expressions in
        MP shorter, but since, for us, these are standards, it's an easy way to
        match up the strings from the FrontPorch "WiFi Space" fields to the
        campus in MP. If your FrontPorch WiFi_Space field already matches
        your Congregation_Name or other existing field, you can use that instead.
        Just update the relevant parts of the query below.
        

https://github.com/Dream-City-Church/mp-wifi-session-to-event-participant

*****************************************
************ BEGIN PROCEDURE ************
****************************************/

/*** Create temporary tables for storing changes ***/
CREATE TABLE #EPInsertAudit (Event_Participant_ID INT)

/*** Create Event Participants based on Wi-Fi actvity ***/
INSERT INTO [dbo].[Event_Participants] (
    Event_ID,
    Participant_ID,
    Participation_Status_ID,
    Time_In,
    Time_Out,
    Notes,
    Domain_ID
    )
OUTPUT INSERTED.Event_Participant_ID
INTO #EPInsertAudit
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
WHERE
    /* First, check if the Event has the Enable_Wifi_Attendance bit set to 1 */
    E.Enable_Wifi_Attendance = 1
    /* Next, does the wifi space abbreviation match the congregation abbreviation */
	AND LEFT(WDS.Wifi_Space,3) = Con.Abbreviation
    /* Did the event end in the past week? Adjust to a timespan of your liking */
	AND E.Event_Start_Date BETWEEN GetDate()-7 AND GetDate()
    /* Last, make sure the Participant isn't already marked present at the Event */
	AND NOT EXISTS(SELECT * FROM Event_Participants EP WHERE EP.Participation_Status_ID IN (3,4) AND EP.Participant_ID = P.Participant_ID AND EP.Event_ID = E.Event_ID)
GROUP BY P.Participant_ID

/*** Add entries to the Audit Log for created Event Participants ***/
INSERT INTO dp_Audit_Log (Table_Name,Record_ID,Audit_Description,User_Name,User_ID,Date_Time)
SELECT 'Event_Participants',#EPInsertAudit.Event_Participant_ID,'Created','Svc Mngr',0,GETDATE()
FROM #EPInsertAudit

/*** Drop the temporary table ***/
DROP TABLE #EPInsertAudit