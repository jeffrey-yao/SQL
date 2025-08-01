/*
Created: Jun 1, 2014 by Jeffrey Yao

Function: Send email notification about the sql service restart
and report the down time window.
It is applicable to sql server 2005 and above version only.

Assumption: The database mail is already configured and workable on the sql server instance.
*/
-- this is test v2
use master
if object_id('dbo.uspRestartAlert', 'P') is not null
	drop proc dbo.uspRestartInfo;
go
create proc dbo.uspRestartAlert
as
begin
	set nocount on;
	declare @curr_trc_file varchar(256), @prev_trc_file varchar(256);
	declare @trc_file_name varchar(128), @trc_file_folder varchar(256);
	declare @trc_num int, @slash_pos int;
	declare @stopTime datetime, @startTime datetime;
	declare @msg varchar(500), @subject varchar(100), @crlf char(2);
	declare @recipients varchar(100), @sqlcmd varchar(max);

	set @recipients = '<your email account>'; -- change to the proper account

	set @crlf = nchar(0x0d) + nchar(0x0a);
	select @curr_trc_file = '', @msg='';

	-- check down time window details
	select @curr_trc_file = [path] from sys.traces
	where id =1 and status =1;

	set @subject= 'Server ' + quotename(@@servername, '[]') + ' has restarted';

	if @curr_trc_file <> ''
	begin
	-- the following is to try to get the number in the current default trace file name,
	-- default trace file has a naming convention like <path>\log_<num>.trc
		set @curr_trc_file = REVERSE(@curr_trc_file);
		set @slash_pos = CHARINDEX('\', @curr_trc_file);
		set @trc_file_folder = reverse(SUBSTRING(@curr_trc_file, @slash_pos, 256));
		set @trc_file_name = reverse(SUBSTRING(@curr_trc_file, 1, @slash_pos-1));
	
		set @trc_num = cast(SUBSTRING(@trc_file_name, 5, len(@trc_file_name)-8) as int) -- 8 = length of "log_" plus ".trc"

		set @curr_trc_file = REVERSE(@curr_trc_file);
		set @prev_trc_file = @trc_file_folder + 'log_' + CAST((@trc_num-1) as varchar(12)) + '.trc'
		select @stopTime=max(starttime) from fn_trace_gettable(@prev_trc_file, 1) -- get the last StartTime of the previous trace 
		select @startTime=min(starttime) from fn_trace_gettable(@curr_trc_file, 1) -- get the first StartTime of the current trace

		set @msg =  'The down time window is from ' + CONVERT(varchar(30), @stopTime, 120) + ' to ' +  CONVERT(varchar(30), @startTime, 120) + ';  ' + @crlf + @crlf
		+ 'The total down time duration is: ['
		+ cast(DATEDIFF(second, @stopTime, @startTime)/60 as varchar(20)) + ' minutes, '  
		+ cast(DATEDIFF(second, @stopTime, @startTime)%60 as varchar(20)) + ' seconds]';
		exec msdb.dbo.sp_send_dbmail @recipients = @recipients, @subject = @subject, @body = @msg--, @body_format='HTML'
	end		
	else -- there is no trace file
		exec msdb.dbo.sp_send_dbmail @recipients = @recipients, @subject = @subject, @body = 'Please check';
end
go

-- set this SP to auto start
if exists (select * from sys.procedures where name='uspRestartAlert')
	exec sp_procoption @ProcName='dbo.uspRestartAlert', @OptionName='startup', @OptionValue='on';
go

