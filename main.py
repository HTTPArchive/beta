# Copyright 2015 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# [START app]
import json
import logging
from time import time

from flask import Flask, request, render_template, abort, url_for


class VizTypes():
    HISTOGRAM = 'histogram'
    TIMESERIES = 'timeseries'

# Ensure reports are updated every 3 hours.
MAX_REPORT_STALENESS = 60 * 60 * 3

last_report_update = 0
reports_json = {}

app = Flask(__name__)

def update_reports():
    global MAX_REPORT_STALENESS
    global last_report_update
    global reports_json

    if (time() - last_report_update) < MAX_REPORT_STALENESS:
        return

    with open('config/reports.json') as reports_file:
        reports_json = json.load(reports_file)
        last_report_update = time()
update_reports()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/about')
def about():
    return render_template('about.html')

@app.route('/faq')
def faq():
    return render_template('faq.html')

@app.route('/reports')
def reports():
    update_reports()
    return render_template('reports.html', reports=reports_json)

@app.route('/reports/<report_id>')
def report(report_id):
    update_reports()

    report = reports_json.get(report_id)
    if not report:
        abort(404)

    dates = report.get('dates')
    if not dates:
        abort(500)

    start = request.args.get('start')
    end = request.args.get('end')

    # Canonicalize single-date formats.
    if end and not start:
        start, end = end, start

    # Canonicalize aliases.
    if start == 'latest':
        start = dates[0]
    elif start == 'earliest':
        start = dates[-1]
    if end == 'latest':
        end = dates[0]
    elif end == 'earliest':
        end = dates[-1]

    # This is longhand for the snapshot (histogram) view.
    if start == end:
        end = None
    
    # This is shorthand for the trends (timeseries) view.
    if not start and not end:
        # TODO: Change the default range from all to most recent 12 months.
        start = dates[-1]
        end = dates[0]

    if start and start not in dates:
        abort(400)
    if end and end not in dates:
        abort(400)

    viz = VizTypes.HISTOGRAM if (start and not end) else VizTypes.TIMESERIES

    if not request.script_root:
        request.script_root = url_for('report', report_id=report_id, _external=True)

    return render_template('report/%s.html' % viz, report=report, start=start, end=end)

@app.errorhandler(400)
def bad_request(e):
    return render_template('400.html', error=e), 400

@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html', error=e), 404

@app.errorhandler(500)
def server_error(e):
    logging.exception('An error occurred during a request.')
    return render_template('500.html', error=e), 500


if __name__ == '__main__':
    # This is used when running locally. Gunicorn is used to run the
    # application on Google App Engine. See entrypoint in app.yaml.
    app.run(host='127.0.0.1', port=8080, debug=True)
# [END app]
