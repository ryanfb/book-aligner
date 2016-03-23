---
---

FUSION_TABLES_URI = 'https://www.googleapis.com/fusiontables/v1'

GOOGLE_BOOKS_API_KEY = 'AIzaSyDkGJOl5EEBahhn1J2kS70FmiRR2uwpFIY'
GOOGLE_API_KEY = 'AIzaSyBoQNYbbHb-MEGa4_oq83_JCLt9cKfd4vg'
# Fusion Tables IDs of the HT-IA indices output from merge-results.rb
HT_IA_TABLE_IDS = ['1ktMz3RDdYEpUu7RTzybkTNCjGg_Vxv0RV1NdC6IL']
# Fusion Tables ID of the IA-GB index output as ia-goog-index.csv
IA_GB_TABLE_ID = '1Tg0cm8gXBUwsBGx53GwGhHYiPpt_6YzG-HrR6Ywl'

HT_REGEX = /^https?:\/\/babel\.hathitrust\.org\/cgi\/pt\?id=(.+)/
IA_REGEX = /^https?:\/\/archive\.org\/details\/(.+)/
GB_REGEX = /^https?:\/\/books\.google\.com\/books\?id=(.+)/

html_id = (input) ->
  input.replace(/[\/:$.,'-]/g,'_')

# wrap values in single quotes and backslash-escape single-quotes
fusion_tables_escape = (value) ->
  "'#{value.replace(/'/g,"\\\'")}'"

fusion_tables_query = (query, callback, error_callback) ->
  console.log "Query: #{query}"
  switch query.split(' ')[0]
    when 'SELECT'
      $.ajax "#{FUSION_TABLES_URI}/query?sql=#{query}&key=#{GOOGLE_API_KEY}",
        type: 'GET'
        dataType: 'json'
        crossDomain: true
        error: (jqXHR, textStatus, errorThrown) ->
          $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text('Error in Fusion Tables AJAX call.'))
          console.log errorThrown
          console.log "AJAX Error: #{textStatus}"
          error_callback() if error_callback?
        success: (data) ->
          console.log data
          if callback?
            callback(data)

ht_biblio_query = (ht_id, score = 0) ->
  $.ajax "http://catalog.hathitrust.org/api/volumes/brief/htid/#{ht_id}.json",
    type: 'GET'
    cache: true
    dataType: 'json'
    crossDomain: true
    error: (jqXHR, textStatus, errorThrown) ->
      $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text('Error in HathiTrust AJAX call.'))
      console.log errorThrown
      console.log "AJAX Error: #{textStatus}"
    success: (data) ->
      console.log data
      ht_object = _.filter(data.items, (item) -> item.htid == ht_id)[0]
      console.log(ht_object)
      if $("##{html_id(ht_id)}").length == 0
        $('#table').DataTable().row.add([
          "<a id='#{html_id(ht_id)}' href='#{ht_url(ht_id)}' target='_blank'>#{ht_id}</a>",
          _.values(data.records)[0].titles[0],
          _.values(data.records)[0].publishDates[0],
          ht_object.enumcron || '',
          null,
          score
        ]).draw(false)
        $('#table').DataTable().columns.adjust().draw()
        # (Original from #{ht_object.orig})

process_ht = (identifier_string) ->
  console.log 'process_ht'
  match = identifier_string.match(HT_REGEX)
  ht_id = match[1].split(';')[0]
  process_ht_id(ht_id, 100)
  ht_query(ht_id)

ht_query = (ht_id, level = 0) ->
  for table_id in HT_IA_TABLE_IDS
    fusion_tables_query "SELECT ia_identifier,score FROM #{table_id} WHERE ht_identifier = #{fusion_tables_escape(ht_id)} ORDER BY score DESC",
      (data) ->
        if data.rows?
          process_ia_id(row[0],(1 - level) * row[1]) for row in data.rows.reverse()
          if level == 0
            ia_query(row[0],1) for row in data.rows.reverse()

ht_url = (ht_id) ->
  "https://babel.hathitrust.org/cgi/pt?id=#{ht_id}"

process_ht_id = (ht_id, score = 0) ->
  ht_biblio_query(ht_id, score)
  console.log ht_id

ia_biblio_query = (ia_id, score = 0) ->
  $.ajax "https://archive.org/metadata/#{ia_id}",
    type: 'GET'
    cache: true
    dataType: 'json'
    crossDomain: true
    error: (jqXHR, textStatus, errorThrown) ->
      $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text('Error in Internet Archive AJAX call.'))
      console.log errorThrown
      console.log "AJAX Error: #{textStatus}"
    success: (data) ->
      console.log data
      if $("##{html_id(ia_id)}").length == 0
        $('#table').DataTable().row.add([
          "<a id='#{html_id(ia_id)}' href='#{ia_url(ia_id)}' target='_blank'>#{ia_id}</a>",
          data.metadata.title,
          data.metadata.year || '',
          data.metadata.volume || '',
          data.metadata.imagecount || '',
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
  ia_query(ia_id)

ia_query = (ia_id, level = 0) ->
  for table_id in HT_IA_TABLE_IDS
    fusion_tables_query "SELECT ht_identifier,score FROM #{table_id} WHERE ia_identifier = #{fusion_tables_escape(ia_id)} ORDER BY score DESC",
      (data) ->
        if data.rows?
          process_ht_id(row[0],(1 - level) * row[1]) for row in data.rows.reverse()
          if level == 0
            ht_query(row[0], 1) for row in data.rows.reverse()

ia_url = (ia_id) ->
  "https://archive.org/details/#{ia_id}"

process_ia_id = (ia_id, score = 0) ->
  ia_biblio_query(ia_id, score)
  console.log ia_id

gb_biblio_query = (gb_id, score = 0) ->
  $.ajax "https://www.googleapis.com/books/v1/volumes/#{gb_id}?key=#{GOOGLE_BOOKS_API_KEY}",
    type: 'GET'
    cache: true
    dataType: 'json'
    crossDomain: true
    error: (jqXHR, textStatus, errorThrown) ->
      $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text("Error in Google Books AJAX call for identifier #{gb_id}"))
      console.log errorThrown
      console.log "AJAX Error: #{textStatus}"
    success: (data) ->
      console.log data
      if $("##{html_id(gb_id)}").length == 0
        $('#table').DataTable().row.add([
          "<a id='#{html_id(gb_id)}' href='#{gb_url(gb_id)}' target='_blank'>#{gb_id}</a>",
          data.volumeInfo.title,
          data.volumeInfo.publishedDate,
          '',
          data.volumeInfo.pageCount || '',
          score
        ]).draw(false)
        $('#table').DataTable().columns.adjust().draw()


process_gb = (identifier_string) ->
  console.log 'process_gb'
  match = identifier_string.match(GB_REGEX)
  gb_id = match[1].split('&')[0]
  process_gb_id(gb_id, 100)
  gb_query(gb_id)

gb_query = (gb_id, level = 0) ->
  fusion_tables_query "SELECT ia_identifier FROM #{IA_GB_TABLE_ID} WHERE gb_identifier = #{fusion_tables_escape(gb_id)}",
    (data) ->
      if data.rows?
        process_ia_id(row[0],(1 - level)*100) for row in data.rows.reverse()
        if level == 0
          ia_query(row[0],1) for row in data.rows.reverse()

gb_url = (gb_id) ->
  "https://books.google.com/books?id=#{gb_id}"

process_gb_id = (gb_id, score = 0) ->
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
