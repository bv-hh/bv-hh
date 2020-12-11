//= require rails-ujs
//= require turbolinks

//= require jquery
//= require popper
//= require bootstrap-sprockets

//= require corejs-typeahead
//
//= require_self

$(function() {
  var suggestSource = $('input.search-input').data('suggest');
  var searchSource = $('input.search-input').data('search');

  var documents = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('title'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      remote: {
        url: suggestSource
        wildcard: 'QUERY'
      }
  });

  typeahead = $('input.search-input').typeahead({highlight: true, hint: false}, {
    name: 'documents',
    display: 'title',
    source: documents,
    limit: 10,
    templates: {
      notFound: function(query) {
        var searchUri = searchSource.replace('QUERY', encodeURIComponent(query.query));
        var template = '<div class="nothing-found">Nach <a href="' + searchUri + '">';
        template += '"' + query.query + '" im Volltext suchen';
        template += '</a> (Enter)</div>';
        return template;
      }
    },
    suggestion: function(suggestion) {
      var template = '<div class="suggestion"><span class="title">' + suggestion.title + '</span> <span class="icd">' + suggestion.icd + '</span><br/>';
      if (suggestion.synonyms) {
        template += '<span class="synonyms">' + suggestion.synonyms + '</span><br/>';
      }

      template += '<span class="meta"><span class="department">' + suggestion.department + '</span> / <span class="type">' + suggestion.type + '</span></span></div>';

      return template;
    }
  });

  typeahead.on('typeahead:select', function(ev, suggestion) {
    window.location = suggestion.path;
  });

};

