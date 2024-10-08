#!bin/python

import sys
import json

from itertools import chain

from flask import abort, Flask, jsonify, request

from flair.nn import Classifier
from flair.data import Sentence
from flair.splitter import SegtokSentenceSplitter

splitter = SegtokSentenceSplitter()
classifier = Classifier.load('de-ner')

app = Flask(__name__)

@app.route('/api/v1/tagger', methods=['POST'])
def tagger():
    if not request.json or not 'text' in request.json:
        abort(400)
    text = request.json['text']

    sentences = splitter.split(text)
    classifier.predict(sentences)

    labels = map(lambda sentence: sentence.get_labels(), sentences)
    labels = list(chain.from_iterable(labels))

    print('Labels: ', labels)

    response = map(lambda label: { 'value': label.value, 'text': label.data_point.text, 'score': label.score }, labels)
    return jsonify(list(response)), 200

if __name__ == "__main__":
    app.run()
