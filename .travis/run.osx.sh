levee test -v tests/
if [[ $? -eq 139 ]]; then
	GLOB="/Library/Logs/DiagnosticReports/levee*"
	for i in {1..10}; do
		sleep 1
		REPORTS=$(ls $HOME$GLOB $GLOB)
		if [[ ! -z "$REPORTS" ]]; then
			cat $REPORTS
			rm $REPORTS
			exit
		fi
	done
fi
