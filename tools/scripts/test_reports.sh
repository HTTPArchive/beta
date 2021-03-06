#!/bin/bash

if [[ "${REPORT_DATE}" == "" || "${REPORT_DATE}" == "LATEST" ]]
then
    REPORT_DATE=$(date +%Y_%m_01)
    CRUX_REPORT_DATE=$(date -d "-1 month" +%Y_%m_01)
else
    CRUX_REPORT_DATE="${REPORT_DATE}"
fi
FAIL=0
NUM_TESTS=0
FAIL_LOG=""
TITLE=""

# These dated report URLs are tested for 200 status
# We test the first and last report for each lens
REPORT_MONTHLY_URLS=$(cat <<-END
https://cdn.httparchive.org/reports/${REPORT_DATE}/bootupJs.json
https://cdn.httparchive.org/reports/${REPORT_DATE}/vulnJs.json
https://cdn.httparchive.org/reports/drupal/${REPORT_DATE}/bootupJs.json
https://cdn.httparchive.org/reports/drupal/${REPORT_DATE}/vulnJs.json
https://cdn.httparchive.org/reports/magento/${REPORT_DATE}/bootupJs.json
https://cdn.httparchive.org/reports/magento/${REPORT_DATE}/vulnJs.json
https://cdn.httparchive.org/reports/wordpress/${REPORT_DATE}/bootupJs.json
https://cdn.httparchive.org/reports/wordpress/${REPORT_DATE}/vulnJs.json
https://cdn.httparchive.org/reports/${CRUX_REPORT_DATE}/cruxCls.json
https://cdn.httparchive.org/reports/${CRUX_REPORT_DATE}/cruxOl.json
END
)


# These timeseries URLs are tested if the date exists in the returned body
# We test the first and last report for each lens
TIMESERIES_URLS=$(cat <<-END
https://cdn.httparchive.org/reports/numUrls.json
https://cdn.httparchive.org/reports/a11yButtonName.json
https://cdn.httparchive.org/reports/drupal/numUrls.json
https://cdn.httparchive.org/reports/drupal/a11yButtonName.json
https://cdn.httparchive.org/reports/magento/numUrls.json
https://cdn.httparchive.org/reports/magento/a11yButtonName.json
https://cdn.httparchive.org/reports/wordpress/numUrls.json
https://cdn.httparchive.org/reports/wordpress/a11yButtonName.json
END
)

# These timeseries URLs are tested if the date exists in the returned body
# For CrUX we always test the month before (unless an explicit date was passed)
# We test the first and last report
CRUX_TIMESERIES_URLS=$(cat <<-END
https://cdn.httparchive.org/reports/cruxFastDcl.json
https://cdn.httparchive.org/reports/cruxSmallCls.json
END
)

echo "Starting testing"

for TEST_URL in ${REPORT_MONTHLY_URLS}
do
    NUM_TESTS=$((NUM_TESTS+1))
    STATUS_CODE=$(curl  -s -o /dev/null -w "%{http_code}" "${TEST_URL}")
    if [[ "${STATUS_CODE}" == "200" ]]
    then
        echo "200 Status code found for ${TEST_URL}"
    else
        echo "Incorrect Status code ${STATUS_CODE} found for ${TEST_URL}"
        FAIL_LOG="${FAIL_LOG}Incorrect Status code ${STATUS_CODE} found for ${TEST_URL}\n"
        FAIL=$((FAIL+1))
    fi
done

for TEST_URL in ${TIMESERIES_URLS}
do
    NUM_TESTS=$((NUM_TESTS+1))
    if curl -s "${TEST_URL}" | grep -q "${REPORT_DATE}"
    then
        echo "${REPORT_DATE} found in body for ${TEST_URL}"
    else
        echo "${REPORT_DATE} not found in body for ${TEST_URL}"
        FAIL_LOG="${FAIL_LOG}${REPORT_DATE} not found in body for ${TEST_URL}\n"
        FAIL=$((FAIL+1))
    fi
done

for TEST_URL in ${CRUX_TIMESERIES_URLS}
do
    NUM_TESTS=$((NUM_TESTS+1))
    if curl -s "${TEST_URL}" | grep -q "${CRUX_REPORT_DATE}"
    then
        echo "${CRUX_REPORT_DATE} found in body for ${TEST_URL}"
    else
        echo "${CRUX_REPORT_DATE} not found in body for ${TEST_URL}"
        FAIL_LOG="${FAIL_LOG}${CRUX_REPORT_DATE} not found in body for ${TEST_URL}\n"
        FAIL=$((FAIL+1))
    fi
done

FAIL_LOG="${FAIL_LOG}\nSee latest log in [GitHub Actions](https://github.com/HTTPArchive/httparchive.org/actions/workflows/monthly-report-checks.yml)
"

if [[ ${FAIL} -ne 0 && ${FAIL} -eq ${NUM_TESTS} ]]
then
    TITLE="All reports have failed for ${REPORT_DATE}"
elif [[ ${FAIL} -ne 0 && ${FAIL} -lt ${NUM_TESTS} ]]
then
    TITLE="Some reports have failed for ${REPORT_DATE}"
fi

# Export the number of fails to GitHub env
if [[ "$GITHUB_ENV" ]]
then
    # shellcheck disable=SC2129
    echo "REPORT_TITLE=${TITLE}" >> "$GITHUB_ENV"
    echo "REPORT_FAILS=${FAIL}" >> "$GITHUB_ENV"
    echo "REPORT_FAIL_LOG<<EOF" >> "$GITHUB_ENV"
    echo -e "${FAIL_LOG}" >> "$GITHUB_ENV"
    echo "EOF" >> "$GITHUB_ENV"
fi

if [[ ${FAIL} -gt 0 ]]
then
    echo "${FAIL} test(s) failed. Exiting 1"
    exit 1
fi

echo "All tests passed"
exit 0
