---
---

FUSION_TABLES_URI = 'https://www.googleapis.com/fusiontables/v1'

GOOGLE_API_KEY = 'AIzaSyACO-ZANrYxHFG44v8kqsfGb6taylh2aDk'
# Fusion Tables ID of the HT-IA index output from book-aligner.rb
HT_IA_TABLE_ID = '1ktMz3RDdYEpUu7RTzybkTNCjGg_Vxv0RV1NdC6IL'
# Fusion Tables ID of the IA-GB index output as ia-goog-index.csv
IA_GB_TABLE_ID = '1Tg0cm8gXBUwsBGx53GwGhHYiPpt_6YzG-HrR6Ywl'

HT_REGEX = /^https?:\/\/babel\.hathitrust\.org\/cgi\/pt\?id=(.+)/
IA_REGEX = /^https?:\/\/archive\.org\/details\/(.+)/
GB_REGEX = /^https?:\/\/books\.google\.com\/books\?id=(.+)/

html_id = (input) ->
  input.replace(/[:.,'-]/g,'_')

# wrap values in single quotes and backslash-escape single-quotes
fusion_tables_escape = (value) ->
  "'#{value.replace(/'/g,"\\\'")}'"

fusion_tables_query = (query, callback, error_callback) ->
  console.log "Query: #{query}"
  switch query.split(' ')[0]
    when 'SELECT'
      $.ajax "#{FUSION_TABLES_URI}/query?sql=#{query}&key=#{GOOGLE_API_KEY}",
        type: 'GET'
        cache: false
        dataType: 'json'
        crossDomain: true
        error: (jqXHR, textStatus, errorThrown) ->
          console.log "AJAX Error: #{textStatus}"
          error_callback() if error_callback?
        success: (data) ->
          console.log data
          if callback?
            callback(data)

no_results = ->
  $('#results').prepend($('<p/>').text('No results.'))

ht_biblio_query = (ht_id, score = 0) ->
  $.ajax "http://catalog.hathitrust.org/api/volumes/brief/htid/#{ht_id}.json",
    type: 'GET'
    cache: true
    dataType: 'json'
    crossDomain: true
    error: (jqXHR, textStatus, errorThrown) ->
      console.log "AJAX Error: #{textStatus}"
    success: (data) ->
      console.log data
      ht_object = _.filter(data.items, (item) -> item.htid == ht_id)[0]
      console.log(ht_object)
      $("##{html_id(ht_id)}").append($('<span/>').text(" - #{_.values(data.records)[0].titles[0]}, #{_.values(data.records)[0].publishDates[0]}, #{ht_object.enumcron}"))
      $('#table').DataTable().row.add([
        "<a href='#{ht_url(ht_id)}' target='_blank'>#{ht_id}</a>",
        _.values(data.records)[0].titles[0],
        _.values(data.records)[0].publishDates[0],
        ht_object.enumcron,
        null,
        score
      ]).draw(false)
      $('#table').DataTable().columns.adjust().draw()
      # (Original from #{ht_object.orig})

process_ht = (identifier_string) ->
  console.log 'process_ht'
  match = identifier_string.match(HT_REGEX)
  ht_id = match[1].split('&')[0]
  process_ht_id(ht_id, 100)
  fusion_tables_query "SELECT ia_identifier,score FROM #{HT_IA_TABLE_ID} WHERE ht_identifier = #{fusion_tables_escape(ht_id)} ORDER BY score DESC",
    (data) ->
      if data.rows?
        process_ia_id(row[0],row[1]) for row in data.rows.reverse()
      else
        no_results()

ht_url = (ht_id) ->
  "https://babel.hathitrust.org/cgi/pt?id=#{ht_id}"

process_ht_id = (ht_id, score = 0) ->
  ht_link = $('<a/>', {href: ht_url(ht_id), target: '_blank'}).text(ht_id)
  ht_biblio_query(ht_id, score)
  console.log ht_id

ia_biblio_query = (ia_id, score = 0) ->
  $.ajax "https://archive.org/metadata/#{ia_id}",
    type: 'GET'
    cache: true
    dataType: 'json'
    crossDomain: true
    error: (jqXHR, textStatus, errorThrown) ->
      console.log "AJAX Error: #{textStatus}"
    success: (data) ->
      console.log data
      $("##{html_id(ia_id)}").append($('<span/>').text(" - #{data.metadata.title}, #{data.metadata.year}, v.#{data.metadata.volume}, #{data.metadata.imagecount} pages"))
      $('#table').DataTable().row.add([
        "<a href='#{ia_url(ia_id)}' target='_blank'>#{ia_id}</a>",
        data.metadata.title,
        data.metadata.year,
        data.metadata.volume || '',
        data.metadata.imagecount,
        score
      ]).draw(false)
      $('#table').DataTable().columns.adjust().draw()

      if data.metadata.source? && data.metadata.source.match(GB_REGEX)
        match = data.metadata.source.match(GB_REGEX)
        gb_id = match[1].split('&')[0]
        process_gb_id(gb_id, score)

process_ia = (identifier_string) ->
  console.log 'process_ia'
  match = identifier_string.match(IA_REGEX)
  ia_id = match[1].split('&')[0]
  process_ia_id(ia_id, 100)
  fusion_tables_query "SELECT ht_identifier,score FROM #{HT_IA_TABLE_ID} WHERE ia_identifier = #{fusion_tables_escape(ia_id)} ORDER BY score DESC",
    (data) ->
      if data.rows?
        process_ht_id(row[0],row[1]) for row in data.rows.reverse()
      else
        no_results()

ia_url = (ia_id) ->
  "https://archive.org/details/#{ia_id}"

process_ia_id = (ia_id, score = 0) ->
  ia_link = $('<a/>',{href: ia_url(ia_id),target: '_blank'}).text(ia_id)
  ia_biblio_query(ia_id, score)
  console.log ia_id

gb_biblio_query = (gb_id, score = 0) ->
  $.ajax "https://www.googleapis.com/books/v1/volumes/#{gb_id}",
    type: 'GET'
    cache: true
    dataType: 'json'
    crossDomain: true
    error: (jqXHR, textStatus, errorThrown) ->
      console.log "AJAX Error: #{textStatus}"
    success: (data) ->
      console.log data
      $("##{html_id(gb_id)}").append($('<span/>').text(" - #{data.volumeInfo.title}, #{data.volumeInfo.publishedDate}, #{data.volumeInfo.pageCount} pages"))
      $('#table').DataTable().row.add([
        "<a href='#{gb_url(gb_id)}' target='_blank'>#{gb_id}</a>",
        data.volumeInfo.title,
        data.volumeInfo.publishedDate,
        '',
        data.volumeInfo.pageCount,
        score
      ]).draw(false)
      $('#table').DataTable().columns.adjust().draw()


process_gb = (identifier_string) ->
  console.log 'process_gb'
  match = identifier_string.match(GB_REGEX)
  gb_id = match[1].split('&')[0]
  process_gb_id(gb_id, 100)
  fusion_tables_query "SELECT ia_identifier FROM #{IA_GB_TABLE_ID} WHERE gb_identifier = #{fusion_tables_escape(gb_id)}",
    (data) ->
      if data.rows?
        process_ia_id(row[0],100) for row in data.rows.reverse()

gb_url = (gb_id) ->
  "https://books.google.com/books?id=#{gb_id}"

process_gb_id = (gb_id, score = 0) ->
  gb_link = $('<a/>',{href: gb_url(gb_id),target: '_blank'}).text(gb_id)
  gb_biblio_query(gb_id, score)
  console.log gb_id

process_identifier = (identifier_string) ->
  $('#results').empty()
  $('#results').append($('<table/>',{id: 'table', class: 'display', cellspacing: 0, width: '100%'}))
  $('#table').DataTable({
    paging: false
    autoWidth: true
    order: [[ 5, "desc" ]]
    columns: [
      { title: "Identifier" }
      { title: "Title" }
      { title: "Year" }
      { title: "Volume" }
      { title: "Pages" }
      { title: "Score" }
    ]
  })
  switch
    when identifier_string.match(HT_REGEX) then process_ht(identifier_string)
    when identifier_string.match(IA_REGEX) then process_ia(identifier_string)
    when identifier_string.match(GB_REGEX) then process_gb(identifier_string)
    else $('#results').prepend($('<p/>').text('Unsupported identifier string.'))

find_matches = ->
  process_identifier($('#identifier_input').val())
  return false

$(document).ready ->
  console.log('ready')
  $('#identifier_form').submit(find_matches)
