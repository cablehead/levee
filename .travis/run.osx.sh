levee test -v tests/
if [[ $? -eq 139 ]]; then
	if [[ -d $HOME/Library/Logs/DiagnosticReports/ ]]; then
		cat $HOME/Library/Logs/DiagnosticReports/levee*
	fi
	if [[ -d /Library/Logs/DiagnosticReports/ ]]; then
		cat /Library/Logs/DiagnosticReports/levee*
	fi
fi
