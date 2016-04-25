levee test -v tests/
if [[ $? -eq 139 ]]; then
	while : ; do
		sleep 1
		REPORTS=$(ls $HOME/Library/Logs/DiagnosticReports/main*)
		if [[ ! -z "$REPORTS" ]]; then
			cat $REPORTS
			rm $REPORTS
			exit
		fi
	done
fi
