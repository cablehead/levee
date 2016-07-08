levee test -vv tests/
CODE=$?
if [[ $CODE -eq 139 ]]; then
	GLOB="/Library/Logs/DiagnosticReports/levee*"
	for i in {1..10}; do
		sleep 1
		REPORTS=$(ls $HOME$GLOB $GLOB)
		if [[ ! -z "$REPORTS" ]]; then
			cat $REPORTS
			rm $REPORTS
			exit 139
		fi
	done
	exit 139
fi
exit $CODE
