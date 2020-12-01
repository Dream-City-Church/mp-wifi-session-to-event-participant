> # Wifi Device Session to Event Participant
> ***A custom Dream City Church procedure for Ministry Platform***
> Version: 1.1
> Author: Stephan Swinford
> Date: 12/1/2020

`This procedure is provided "as is" with no warranties expressed or implied.`

**Description**
This procedure creates Event Participant records for any Participant/Contact with an associated WiFi Device and WiFi Session during an Event with the Enable_WiFi_Attendance bitfield set to True.

**Requirements**

 1. FrontPorch integration.
 2. We have added a custom "Abbreviation" VARCHAR column to our Congregations table. We use that abbreviation for several purposes, but for this procedure in particular we use it to match a FrontPorch space to a Congregation in MP.
 3. A column in your Events tabled called "Enable_Wifi_Attendance" with the type of "bit".
 4. A SQL Server Agent Job that calls this procedure needs to be created, or a step needs to be added to an existing daily job. The job can run as frequently as you like as the procedure checks for existing records before creating a new one.
    * NOTE: Do not use any of the built-in MinistryPlatform jobs as ThinkMinistry may update those jobs at any time and remove your custom Job Step. Create a new Job with a Daily trigger.
    * Job Step details:
      **Step Name:** Wifi Session to Event Participant (*your choice on name*)
      **Type:** Transact-SQL script (T-SQL)
      **Database:** MinistryPlatform
      **Command:** EXEC [dbo].[service_wifi_session_event_participant] @DomainID = 1

**Installation**
1. Add the required integration and set up the custom columns as outlined in the Requirements section.
2. Copy and execute [wifi_session_to_event_participant.sql](wifi_session_to_event_participant.sql) in SSMS
3. Set up your SQL Job as outlined in Requirements #4.
