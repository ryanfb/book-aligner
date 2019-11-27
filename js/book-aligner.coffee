---
---

API_GATEWAY_URI = 'https://sl32iw0891.execute-api.us-east-1.amazonaws.com/book-aligner'

GOOGLE_BOOKS_URI = 'https://www.googleapis.com/books/v1/volumes'

GOOGLE_BOOKS_API_KEY = 'AIzaSyDkGJOl5EEBahhn1J2kS70FmiRR2uwpFIY'

HT_REGEX = /^https?:\/\/babel\.hathitrust\.org\/cgi\/pt\?id=(.+)/
IA_REGEX = /^https?:\/\/(www\.)?archive\.org\/(details|stream)\/(.+)[#/]?/
GB_REGEX = /^https?:\/\/books\.google\.com\/books\?id=(.+)/
HDL_REGEX = /^https?:\/\/hdl\.handle\.net\/2027\/(.+)\/?/
HT_CATALOG_REGEX = /^https?:\/\/catalog\.hathitrust\.org\/Record\/(\d{9})/

QUERIED_IDS = {}

html_id = (input) ->
  input.replace(/[\/:$.,'-]/g,'_')

ht_rights = (usRightsString) ->
  if usRightsString? and (usRightsString.toLowerCase() == 'full view')
    return ''
  else
    return " \uD83D\uDD12"

ht_biblio_query = (ht_id, score = 0) ->
  if $("##{html_id(ht_id)}").length == 0
    console.log "Adding HT: #{ht_id}"
    ht_query(ht_id)
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
        # console.log("HT metadata for #{ht_id}:")
        # console.log data
        ht_object = _.filter(data.items, (item) -> item.htid == ht_id)[0]
        # console.log(ht_object)
        if $("##{html_id(ht_id)}").length == 0
          $('#table').DataTable().row.add([
            '<img src="https://www.hathitrust.org/favicon.ico" width="16" height="16"/>',
            "<a id='#{html_id(ht_id)}' href='#{ht_url(ht_id)}' target='_blank'>#{ht_id}</a>" + ht_rights(data.items[0]['usRightsString']),
            _.values(data.records)[0].titles[0] || '',
            _.values(data.records)[0].publishDates[0] || '',
            ht_object.enumcron || '',
            '',
            oclc_href(_.values(data.records)[0].oclcs[0]) || '',
            score || 0
          ]).draw(false)
          $('#table').DataTable().columns.adjust().draw()
          # (Original from #{ht_object.orig})
          for identifier_type in ['oclc','lccn','isbn']
            identifiers = _.uniq(_.values(data.records)[0]["#{identifier_type}s"])
            if identifiers? and (identifiers.length > 0)
              industry_identifier_query(identifier_type, identifier) for identifier in identifiers

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
      # console.log data
      ht_ids = (item.htid for item in data.items) # _.map(data.items, (item) -> item.htid)
      # console.log(ht_ids)
      for ht_id in ht_ids
        process_ht_id(ht_id, 100)

process_ht = (identifier_string) ->
  console.log 'process_ht'
  match = identifier_string.match(HT_REGEX)
  ht_id = match[1].split(';')[0]
  process_ht_id(ht_id, 100)

process_hdl = (identifier_string) ->
  console.log 'process_hdl'
  match = identifier_string.match(HDL_REGEX)
  ht_id = match[1].split(';')[0]
  process_ht_id(ht_id, 100)

ht_query = (ht_id, level = 0) ->
  if ht_id not in QUERIED_IDS['ht']
    QUERIED_IDS['ht'].push ht_id
    $.ajax "#{API_GATEWAY_URI}/ht-ia/ht/#{encodeURIComponent(ht_id)}",
      type: 'GET'
      cache: true
      dataType: 'json'
      crossDomain: true
      error: (jqXHR, textStatus, errorThrown) ->
        $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text('Error in Book Aligner HT/IA AJAX call.'))
        console.log errorThrown
        console.log "AJAX Error: #{textStatus}"
      success: (data) ->
        if data.length
          process_ia_id(result.ia_identifier, (1 - level) * parseInt(result.score)) for result in data
          if level == 0
            ia_query(result.ia_identifier,1) for result in data

ht_url = (ht_id) ->
  "https://babel.hathitrust.org/cgi/pt?id=#{ht_id}"

oclc_href = (oclc_id) ->
  if oclc_id?
    "<a target='_blank' href='http://www.worldcat.org/oclc/#{oclc_id}'>#{oclc_id}</a>"

process_ht_id = (ht_id, score = 0) ->
  ht_biblio_query(ht_id, score)

filter_ia_external_ids = (external_ids, type) ->
  identifier_regex = new RegExp("^urn:#{type}:(.+)$")
  matching_ids = external_ids.filter (external_id) -> external_id.match(identifier_regex)
  matching_id.match(identifier_regex)[1] for matching_id in matching_ids

ia_biblio_query = (ia_id, score = 0) ->
  if $("##{html_id(ia_id)}").length == 0
    console.log("Adding IA: #{ia_id}")
    ia_query(ia_id)
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
        # console.log "IA metadata for #{ia_id}:"
        # console.log data
        if $("##{html_id(ia_id)}").length == 0
          $('#table').DataTable().row.add([
            '<img src="https://archive.org/favicon.ico" width="16" height="16"/>',
            "<a id='#{html_id(ia_id)}' href='#{ia_url(ia_id)}' target='_blank'>#{ia_id}</a>",
            data.metadata.title,
            data.metadata.year || data.metadata.date || '',
            data.metadata.volume || '',
            data.metadata.imagecount || '',
            oclc_href(data.metadata['oclc-id']) || '',
            score || 0
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
            queriable_identifiers = []
            if $.isArray(data.metadata['related-external-id'])
              queriable_identifiers = queriable_identifiers.concat(filter_ia_external_ids(data.metadata['related-external-id'],identifier_type_mapping[identifier_type]))
            if data.metadata[identifier_type]?
              if $.isArray(data.metadata[identifier_type])
                queriable_identifiers = queriable_identifiers.concat(data.metadata[identifier_type])
              else
                queriable_identifiers.push(data.metadata[identifier_type])
            industry_identifier_query(identifier_type_mapping[identifier_type], identifier) for identifier in _.uniq(queriable_identifiers)

process_ia = (identifier_string, score = 100) ->
  console.log 'process_ia'
  match = identifier_string.match(IA_REGEX)
  ia_id = match[3].split(/[&#]/)[0]
  process_ia_id(ia_id, score)

ia_query = (ia_id, level = 0) ->
  if ia_id not in QUERIED_IDS['ia']
    QUERIED_IDS['ia'].push ia_id
    $.ajax "#{API_GATEWAY_URI}/ht-ia/ia/#{ia_id}",
      type: 'GET'
      cache: true
      dataType: 'json'
      crossDomain: true
      error: (jqXHR, textStatus, errorThrown) ->
        $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text('Error in Book Aligner IA/HT AJAX call.'))
        console.log errorThrown
        console.log "AJAX Error: #{textStatus}"
      success: (data) ->
        if data.length
          process_ht_id(result.ht_identifier, (1 - level) * parseInt(result.score)) for result in data
          if level == 0
            ht_query(result.ht_identifier,1) for result in data
    $.ajax "#{API_GATEWAY_URI}/ia-gb/ia/#{ia_id}",
      type: 'GET'
      cache: true
      dataType: 'json'
      crossDomain: true
      error: (jqXHR, textStatus, errorThrown) ->
        $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text('Error in Book Aligner IA/GB AJAX call.'))
        console.log errorThrown
        console.log "AJAX Error: #{textStatus}"
      success: (data) ->
        if data.length
          process_gb_id(result.gb_identifier, (1 - level) * 100) for result in data
          if level == 0
            gb_query(result.gb_identifier,1) for result in data

ia_url = (ia_id) ->
  "https://archive.org/details/#{ia_id}"

process_ia_id = (ia_id, score = 0) ->
  ia_biblio_query(ia_id, score)

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
        if jqXHR.responseJSON.error.errors[0].domain == 'usageLimits'
          unless $('#gb_quota_error').length
            $('#results').append($('<div/>',{id: 'gb_quota_error', class: 'alert alert-danger', role: 'alert'}).text("Error in Google Books AJAX call: Google Books API Quota daily limit exceeded. Please try again tomorrow for improved results."))
        else
          $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text("Error in Google Books AJAX call for identifier #{identifier}"))
          console.log jqXHR
          console.log errorThrown
          console.log "AJAX Error: #{textStatus}"
      success: (data) ->
        # console.log "#{identifier_type} query #{identifier} Google Books result:"
        # console.log data
        if data and data.items and (data.items.length > 0)
          for item in data.items
            gb_biblio_query(item.id, score)
    $.ajax "https://catalog.hathitrust.org/api/volumes/brief/json/#{identifier_type}:#{identifier}",
      type: 'GET'
      cache: true
      dataType: 'json'
      crossDomain: true
      error: (jqXHR, textStatus, errorThrown) ->
        $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text('Error in HathiTrust AJAX call.'))
        console.log errorThrown
        console.log "AJAX Error: #{textStatus}"
      success: (data) ->
        # console.log "#{identifier_type} query #{identifier} HathiTrust result:"
        # console.log data
        ht_biblio_query(item.htid) for item in _.values(data)[0].items
    $.ajax "https://openlibrary.org/api/books?bibkeys=#{identifier_type}:#{identifier}&format=json&jscmd=data",
      type: 'GET'
      cache: true
      dataType: 'json'
      crossDomain: true
      error: (jqXHR, textStatus, errorThrown) ->
        $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text('Error in Internet Archive AJAX call.'))
        console.log errorThrown
        console.log "AJAX Error: #{textStatus}"
      success: (data) ->
        # console.log "#{identifier_type} query #{identifier} Internet Archive result:"
        # console.log data
        if data? and !($.isEmptyObject(data))
          ebooks = _.values(data)[0].ebooks
          if ebooks? and (ebooks.length > 0)
            for ebook in ebooks
              if ebook.preview_url.match(IA_REGEX)
                process_ia(ebook.preview_url)

gb_rights = (accessViewStatus) ->
  if accessViewStatus? and (accessViewStatus == 'FULL_PUBLIC_DOMAIN')
    return ''
  else
    return " \uD83D\uDD12"

gb_biblio_query = (gb_id, score = 0) ->
  if $("##{html_id(gb_id)}").length == 0
    console.log("Adding GB: #{gb_id}")
    gb_query(gb_id)
    $.ajax "#{GOOGLE_BOOKS_URI}/#{gb_id}?projection=full&key=#{GOOGLE_BOOKS_API_KEY}",
      type: 'GET'
      cache: true
      dataType: 'json'
      crossDomain: true
      error: (jqXHR, textStatus, errorThrown) ->
        if jqXHR.responseJSON.error.errors[0].domain == 'usageLimits'
          unless $('#gb_quota_error').length
            $('#results').append($('<div/>',{id: 'gb_quota_error', class: 'alert alert-danger', role: 'alert'}).text("Error in Google Books AJAX call: Google Books API Quota daily limit exceeded. Please try again tomorrow for improved results."))
        else
          $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text("Error in Google Books AJAX call for GB identifier #{gb_id}"))
          console.log jqXHR.responseJSON
          console.log errorThrown
          console.log "AJAX Error: #{textStatus}"
      success: (data) ->
        # console.log("GB metadata for #{gb_id}:")
        # console.log data
        if $("##{html_id(gb_id)}").length == 0
          $('#table').DataTable().row.add([
            '<img src="https://www.google.com/favicon.ico" width="16" height="16"/>',
            "<a id='#{html_id(gb_id)}' href='#{gb_url(gb_id)}' target='_blank'>#{gb_id}</a>" + gb_rights(data.accessInfo.accessViewStatus),
            data.volumeInfo.title || '',
            data.volumeInfo.publishedDate || '',
            '',
            data.volumeInfo.printedPageCount || data.volumeInfo.pageCount || '',
            '',
            score || 0
          ]).draw(false)
          $('#table').DataTable().columns.adjust().draw()
          if data.volumeInfo.industryIdentifiers? and (data.volumeInfo.industryIdentifiers.length > 0)
            for industry_identifier in data.volumeInfo.industryIdentifiers
              if (industry_identifier.type == 'ISBN_13') or (industry_identifier.type == 'ISBN_10')
                industry_identifier_query('isbn', industry_identifier.identifier)

process_gb = (identifier_string) ->
  console.log 'process_gb'
  match = identifier_string.match(GB_REGEX)
  gb_id = match[1].split('&')[0]
  process_gb_id(gb_id, 100)

gb_query = (gb_id, level = 0) ->
  if gb_id not in QUERIED_IDS['gb']
    QUERIED_IDS['gb'].push gb_id
    $.ajax "#{API_GATEWAY_URI}/ia-gb/gb/#{gb_id}",
      type: 'GET'
      cache: true
      dataType: 'json'
      crossDomain: true
      error: (jqXHR, textStatus, errorThrown) ->
        $('#results').append($('<div/>',{class: 'alert alert-danger', role: 'alert'}).text('Error in Book Aligner GB/IA AJAX call.'))
        console.log errorThrown
        console.log "AJAX Error: #{textStatus}"
      success: (data) ->
        if data.length
          process_ia_id(result.ia_identifier, (1 - level) * 100) for result in data
          if level == 0
            ia_query(result.ia_identifier,1) for result in data

gb_url = (gb_id) ->
  "https://books.google.com/books?id=#{gb_id}"

process_gb_id = (gb_id, score = 0) ->
  gb_biblio_query(gb_id, score)

reset_queried_ids = ->
  QUERIED_IDS = {
    'isbn': [],
    'oclc': [],
    'lccn': [],
    'ht': [],
    'gb': [],
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
  process_identifier($('#identifier_input').val().trim())
  return false

$(document).ready ->
  console.log('ready')
  $('#loadingDiv').hide()
  $(document).ajaxStart -> $('#loadingDiv').show()
  $(document).ajaxStop -> $('#loadingDiv').hide()
  $('#identifier_form').submit(find_matches)
