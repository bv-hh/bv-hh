//= require rails-ujs
//= require turbolinks

//= require jquery
//= require popper

//= require bootstrap/util
//= require bootstrap/dropdown
//= require bootstrap/collapse
//= require bootstrap/tooltip

//= require corejs-typeahead

//= require chartkick
//= require Chart.bundle

//= require_self

document.addEventListener("turbolinks:load", function() {
  $('[data-toggle="tooltip"]').tooltip();
  initSearch();
});

document.addEventListener("turbolinks:before-cache", function () {
  $('[data-toggle="tooltip"]').tooltip('hide');
});

function initSearch() {
  var documentsSuggestSource = $('input.search-input').data('suggest-documents');
  var minutesSuggestSource = $('input.search-input').data('suggest-minutes');
  var searchSource = $('input.search-input').data('search');

  var documents = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('title'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      remote: {
        url: documentsSuggestSource,
        wildcard: 'QUERY'
      }
  });

  var minutes = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('title'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      remote: {
        url: minutesSuggestSource,
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
        template += '"' + query.query + '" in allen Drucksachen suchen';
        template += '</a> (Enter)</div>';
        return template;
      },
      suggestion: function(suggestion) {
        var template = '<div class="suggestion"><span class="title">' + suggestion.title + '</span> <br/>';

        template += '<span class="meta"><span class="district">' + suggestion.district + '</span> <span class="kind"> / ' + suggestion.kind + '</span>';
        template += ' <span class="number">' + suggestion.number + '</span></span></div>'

        return template;
      }
    },
  }, {
    name: 'minutes',
    display: 'title',
    source: minutes,
    limit: 10,
    templates: {
      notFound: function(query) {
        var searchUri = searchSource.replace('QUERY', encodeURIComponent(query.query));
        var template = '<div class="nothing-found">Nach <a href="' + searchUri + '">';
        template += '"' + query.query + '" in allen Protokollen suchen';
        template += '</a> (Enter)</div>';
        return template;
      },
      suggestion: function(suggestion) {
        var template = '<div class="suggestion"><span class="title">' + suggestion.title + '</span> <br/>';

        template += '<span class="meta"><span class="district">' + suggestion.district + '</span> <span class="committee"> / ' + suggestion.committee + '</span>';
        template += ' <span class="date">' + suggestion.date + '</span></span></div>'

        return template;
      }
    },
  });

  typeahead.on('typeahead:select', function(ev, suggestion) {
    window.location = suggestion.path;
  });

};
