---
---

FUSION_TABLES_URI = 'https://www.googleapis.com/fusiontables/v2'
GOOGLE_BOOKS_URI = 'https://www.googleapis.com/books/v1/volumes'

GOOGLE_BOOKS_API_KEY = 'AIzaSyDkGJOl5EEBahhn1J2kS70FmiRR2uwpFIY'
GOOGLE_API_KEY = 'AIzaSyBoQNYbbHb-MEGa4_oq83_JCLt9cKfd4vg'
# Fusion Tables IDs of the HT-IA indices output from merge-results.rb
HT_IA_TABLE_IDS = ['1Y5uDWMjUzrk6z_8l_C1NzLq9yUSpgS5n473N9dXL','1JNR9hJogOdwsYrNRH0Au_XlLELFViqVXhUg0pgBh']
# Fusion Tables ID of the IA-GB index output as ia-goog-index.csv
IA_GB_TABLE_ID = '1Tg0cm8gXBUwsBGx53GwGhHYiPpt_6YzG-HrR6Ywl'

HT_REGEX = /^https?:\/\/babel\.hathitrust\.org\/cgi\/pt\?id=(.+)/
IA_REGEX = /^https?:\/\/(www\.)?archive\.org\/details\/(.+)\/?/
GB_REGEX = /^https?:\/\/books\.google\.com\/books\?id=(.+)/
HDL_REGEX = /^https?:\/\/hdl\.handle\.net\/2027\/(.+)\/?/
HT_CATALOG_REGEX = /^https?:\/\/catalog\.hathitrust\.org\/Record\/(\d{9})/

QUERIED_IDS = {}

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
          # $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text("Error in Fusion Tables AJAX call."))
          console.log jqXHR
          console.log errorThrown
          console.log "AJAX Error: #{textStatus}"
          error_callback() if error_callback?
          console.log "Retrying Fusion Tables query: #{query}"
          fusion_tables_query(query, callback, error_callback)
        success: (data) ->
          console.log data
          if callback?
            callback(data)

ht_biblio_query = (ht_id, score = 0) ->
  if $("##{html_id(ht_id)}").length == 0
    $.ajax "https://catalog.hathitrust.org/api/volumes/brief/htid/#{ht_id}.json",
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
            '<img src="https://www.hathitrust.org/favicon.ico" width="16" height="16"/>',
            "<a id='#{html_id(ht_id)}' href='#{ht_url(ht_id)}' target='_blank'>#{ht_id}</a>",
            _.values(data.records)[0].titles[0],
            _.values(data.records)[0].publishDates[0],
            ht_object.enumcron || '',
            '',
            oclc_href(_.values(data.records)[0].oclcs[0]) || '',
            score
          ]).draw(false)
          $('#table').DataTable().columns.adjust().draw()
          # (Original from #{ht_object.orig})
          oclcs = _.uniq(_.values(data.records)[0].oclcs)
          if oclcs? and (oclcs.length > 0)
            industry_identifier_query('oclc', oclc_id) for oclc_id in oclcs
          lccns = _.uniq(_.values(data.records)[0].lccns)
          if lccns? and (lccns.length > 0)
            industry_identifier_query('lccn', lccn_id) for lccn_id in lccns
          isbns = _.uniq(_.values(data.records)[0].isbns)
          if isbns? and (isbns.length > 0)
            industry_identifier_query('isbn', isbn_id) for isbn_id in isbns

process_ht_catalog = (identifier_string) ->
  console.log 'process_ht_catalog'
  match = identifier_string.match(HT_CATALOG_REGEX)
  ht_record_id = match[1]
  $.ajax "https://catalog.hathitrust.org/api/volumes/brief/recordnumber/#{ht_record_id}.json",
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
      ht_ids = (item.htid for item in data.items) # _.map(data.items, (item) -> item.htid)
      console.log(ht_ids)
      for ht_id in ht_ids
        process_ht_id(ht_id, 100)
        ht_query(ht_id)

process_ht = (identifier_string) ->
  console.log 'process_ht'
  match = identifier_string.match(HT_REGEX)
  ht_id = match[1].split(';')[0]
  process_ht_id(ht_id, 100)
  ht_query(ht_id)

process_hdl = (identifier_string) ->
  console.log 'process_hdl'
  match = identifier_string.match(HDL_REGEX)
  ht_id = match[1].split(';')[0]
  process_ht_id(ht_id, 100)
  ht_query(ht_id)

ht_query = (ht_id, level = 0) ->
  if ht_id not in QUERIED_IDS['ht']
    QUERIED_IDS['ht'].push ht_id
    for table_id in HT_IA_TABLE_IDS
      fusion_tables_query "SELECT ia_identifier,score FROM #{table_id} WHERE ht_identifier = #{fusion_tables_escape(ht_id)}",
        (data) ->
          if data.rows?
            process_ia_id(row[0],(1 - level) * row[1]) for row in data.rows.reverse()
            if level == 0
              ia_query(row[0],1) for row in data.rows.reverse()

ht_url = (ht_id) ->
  "https://babel.hathitrust.org/cgi/pt?id=#{ht_id}"

oclc_href = (oclc_id) ->
  if oclc_id?
    "<a target='_blank' href='http://www.worldcat.org/oclc/#{oclc_id}'>#{oclc_id}</a>"

process_ht_id = (ht_id, score = 0) ->
  ht_biblio_query(ht_id, score)
  console.log ht_id

ia_biblio_query = (ia_id, score = 0) ->
  if $("##{html_id(ia_id)}").length == 0
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
            '<img src="http://archive.org/favicon.ico" width="16" height="16"/>',
            "<a id='#{html_id(ia_id)}' href='#{ia_url(ia_id)}' target='_blank'>#{ia_id}</a>",
            data.metadata.title,
            data.metadata.year || data.metadata.date || '',
            data.metadata.volume || '',
            data.metadata.imagecount || '',
            oclc_href(data.metadata['oclc-id']) || '',
            score
          ]).draw(false)
          $('#table').DataTable().columns.adjust().draw()

          if data.metadata.source? && data.metadata.source.match(GB_REGEX)
            match = data.metadata.source.match(GB_REGEX)
            gb_id = match[1].split('&')[0]
            process_gb_id(gb_id, score)
          identifier_type_mapping = {
            'lccn': 'lccn',
            'isbn': 'isbn',
            'oclc-id': 'oclc'
          }
          for identifier_type in ['lccn','isbn','oclc-id']
            if data.metadata[identifier_type]?
              if $.isArray(data.metadata[identifier_type])
                industry_identifier_query(identifier_type_mapping[identifier_type], identifier) for identifier in _.uniq(data.metadata[identifier_type])
              else
                industry_identifier_query(identifier_type_mapping[identifier_type], data.metadata[identifier_type])

process_ia = (identifier_string) ->
  console.log 'process_ia'
  match = identifier_string.match(IA_REGEX)
  ia_id = match[2].split('&')[0]
  process_ia_id(ia_id, 100)
  ia_query(ia_id)

ia_query = (ia_id, level = 0) ->
  if ia_id not in QUERIED_IDS['ia']
    QUERIED_IDS['ia'].push ia_id
    for table_id in HT_IA_TABLE_IDS
      fusion_tables_query "SELECT ht_identifier,score FROM #{table_id} WHERE ia_identifier = #{fusion_tables_escape(ia_id)}",
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

industry_identifier_query = (identifier_type, identifier, score = 0) ->
  if identifier not in QUERIED_IDS[identifier_type]
    console.log "#{identifier_type} query: #{identifier}"
    QUERIED_IDS[identifier_type].push identifier
    $.ajax "#{GOOGLE_BOOKS_URI}?q=#{identifier_type}:#{identifier}&key=#{GOOGLE_BOOKS_API_KEY}",
      type: 'GET'
      cache: true
      dataType: 'json'
      crossDomain: true
      error: (jqXHR, textStatus, errorThrown) ->
        $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text("Error in Google Books AJAX call for identifier #{gb_id}"))
        console.log jqXHR
        console.log errorThrown
        console.log "AJAX Error: #{textStatus}"
      success: (data) ->
        console.log "#{identifier_type} query #{identifier} result:"
        console.log data
        if data and data.items and (data.items.length > 0)
          for item in data.items
            process_gb_id(item.id, score)
            gb_query(item.id)

gb_biblio_query = (gb_id, score = 0) ->
  if $("##{html_id(gb_id)}").length == 0
    $.ajax "#{GOOGLE_BOOKS_URI}/#{gb_id}?projection=full&key=#{GOOGLE_BOOKS_API_KEY}",
      type: 'GET'
      cache: true
      dataType: 'json'
      crossDomain: true
      error: (jqXHR, textStatus, errorThrown) ->
        $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text("Error in Google Books AJAX call for identifier #{gb_id}"))
        console.log jqXHR
        console.log errorThrown
        console.log "AJAX Error: #{textStatus}"
      success: (data) ->
        console.log data
        if $("##{html_id(gb_id)}").length == 0
          $('#table').DataTable().row.add([
            '<img src="http://www.google.com/favicon.ico" width="16" height="16"/>',
            "<a id='#{html_id(gb_id)}' href='#{gb_url(gb_id)}' target='_blank'>#{gb_id}</a>",
            data.volumeInfo.title,
            data.volumeInfo.publishedDate,
            '',
            data.volumeInfo.printedPageCount || data.volumeInfo.pageCount || '',
            '',
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

reset_queried_ids = ->
  QUERIED_IDS = {
    'isbn': [],
    'oclc': [],
    'lccn': [],
    'ht': [],
    'ia': []
  }

process_identifier = (identifier_string) ->
  reset_queried_ids()
  $('#results').empty()
  $('#results').append($('<table/>',{id: 'table', class: 'display', cellspacing: 0, width: '100%'}))
  $('#table').DataTable({
    paging: false
    autoWidth: true
    order: [[ 7, "desc" ]]
    columns: [
      { title: "", orderable: false }
      { title: "Identifier" }
      { title: "Title" }
      { title: "Year" }
      { title: "Volume" }
      { title: "Pages" }
      { title: "OCLC" }
      { title: "Score" }
    ]
  })
  switch
    when identifier_string.match(HT_REGEX) then process_ht(identifier_string)
    when identifier_string.match(HT_CATALOG_REGEX) then process_ht_catalog(identifier_string)
    when identifier_string.match(HDL_REGEX) then process_hdl(identifier_string)
    when identifier_string.match(IA_REGEX) then process_ia(identifier_string)
    when identifier_string.match(GB_REGEX) then process_gb(identifier_string)
    else $('#results').prepend($('<p/>').text('Unsupported identifier string.'))

find_matches = ->
  process_identifier($('#identifier_input').val())
  return false

$(document).ready ->
  console.log('ready')
  $('#loadingDiv').hide()
  $(document).ajaxStart -> $('#loadingDiv').show()
  $(document).ajaxStop -> $('#loadingDiv').hide()
  $('#identifier_form').submit(find_matches)
