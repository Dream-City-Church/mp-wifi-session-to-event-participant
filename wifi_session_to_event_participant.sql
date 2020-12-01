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
Date: 12/1/2020

This procedure is provided "as is" with no warranties expressed or implied.

-- Description --
This procedure creates Event Participant records for any Participant/Contact
with an associated WiFi Device and WiFi Session during an Event with the
Enable_WiFi_Attendance bitfield set to True.

--Requirements --
 1. FrontPorch integration.

 2. We have added a custom "Abbreviation" VARCHAR column to our Congregations
 table. We use that abbreviation for several purposes, but for this procedure
 in particular we use it to match a FrontPorch space to a Congregation in MP.

 3. A column in your Events tabled called "Enable_Wifi_Attendance" with the
 type of "bit".

 4. A SQL Server Agent Job that calls this procedure needs to be created, or
 a step needs to be added to an existing daily job. The job can run as
 frequently as you like as the procedure checks for existing records before
 creating a new one.
    * NOTE: Do not use any of the built-in MinistryPlatform jobs as ThinkMinistry
    may update those jobs at any time and remove your custom Job Step. Create a
    new Job with a Daily trigger.
    * Job Step details:
      **Step Name:** Wifi Session to Event Participant (*your choice on name*)
      **Type:** Transact-SQL script (T-SQL)
      **Database:** MinistryPlatform
      **Command:** EXEC [dbo].[service_wifi_session_event_participant] @DomainID = 1

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