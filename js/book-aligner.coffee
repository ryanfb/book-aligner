---
---

FUSION_TABLES_URI = 'https://www.googleapis.com/fusiontables/v1'

GOOGLE_API_KEY = 'AIzaSyACO-ZANrYxHFG44v8kqsfGb6taylh2aDk'
FUSION_TABLES_ID = '1ktMz3RDdYEpUu7RTzybkTNCjGg_Vxv0RV1NdC6IL'

HT_REGEX = /^https?:\/\/babel\.hathitrust\.org\/cgi\/pt\?id=(.+)/
IA_REGEX = /^https?:\/\/archive\.org\/details\/(.+)/
GB_REGEX = /^https?:\/\/books\.google\.com\/books\?id=(.+)/

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

process_ht = (identifier_string) ->
  console.log 'process_ht'
  match = identifier_string.match(HT_REGEX)
  console.log match[1]
  fusion_tables_query "SELECT ia_identifier FROM #{FUSION_TABLES_ID} WHERE ht_identifier = #{fusion_tables_escape(match[1])} ORDER BY score DESC", (data) -> process_ia_id(row[0]) for row in data.rows

process_ht_id = (ht_id) ->
  console.log ht_id

process_ia = (identifier_string) ->
  console.log 'process_ia'
  match = identifier_string.match(IA_REGEX)
  console.log match[1]
  fusion_tables_query "SELECT ht_identifier FROM #{FUSION_TABLES_ID} WHERE ia_identifier = #{fusion_tables_escape(match[1])} ORDER BY score DESC", (data) -> process_ht_id(row[0]) for row in data.rows

process_ia_id = (ia_id) ->
  console.log ia_id

process_gb = (identifier_string) ->
  console.log 'process_gb'
  match = identifier_string.match(GB_REGEX)
  console.log match[1]

process_identifier = (identifier_string) ->
  console.log identifier_string
  switch
    when identifier_string.match(HT_REGEX) then process_ht(identifier_string)
    when identifier_string.match(IA_REGEX) then process_ia(identifier_string)
    when identifier_string.match(GB_REGEX) then process_gb(identifier_string)
    else alert('Unsupported identifier string.')

find_matches = ->
  process_identifier($('#identifier_input').val())
  return false

$(document).ready ->
  console.log('ready')
  $('#identifier_form').submit(find_matches)
