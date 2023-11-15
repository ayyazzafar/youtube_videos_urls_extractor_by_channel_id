from flask import Flask, jsonify, request
import subprocess
import shlex
from flask_cors import CORS  # Import the CORS module

app = Flask(__name__)
CORS(app)  # This will enable CORS for all routes


@app.route('/get_youtube_urls', methods=['GET'])
def get_youtube_urls():
    channel_url = request.args.get('channel_url')
    if not channel_url:
        return jsonify({"error": "No channel URL provided"}), 400

    command = f"yt-dlp -i --get-url --flat-playlist {shlex.quote(channel_url)}"
    process = subprocess.Popen(
        command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = process.communicate()

    if process.returncode != 0:
        return jsonify({"error": "Failed to retrieve URLs"}), 500

    urls = out.decode().splitlines()
    return jsonify(urls)


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=80)
