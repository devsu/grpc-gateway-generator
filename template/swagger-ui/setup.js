var loadJson = function (url) {
  $('#auth_container').empty();
  window.swaggerUi = new SwaggerUi({
    url: url,
    dom_id: "swagger-ui-container",
    supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],
    onComplete: function (swaggerApi, swaggerUi) {
      if (typeof initOAuth == "function") {
        initOAuth({
          clientId: "your-client-id",
          clientSecret: "your-client-secret-if-required",
          realm: "your-realms",
          appName: "your-app-name",
          scopeSeparator: " ",
          additionalQueryStringParams: {}
        });
      }

      if (window.SwaggerTranslator) {
        window.SwaggerTranslator.translate();
      }
    },
    onFailure: function (data) {
      log("Unable to Load SwaggerUI");
    },
    docExpansion: "none",
    jsonEditor: false,
    defaultModelRendering: 'schema',
    showRequestHeaders: false
  });

  window.swaggerUi.load();
};

var getTitle = function (filename) {
  return filename.substring(0, filename.indexOf( ".swagger.json" )).split('/').pop();
}

var appendDefinitionLink = function (filename) {
  var title = getTitle(filename);
  var onclick = 'loadJson(\'' + filename + '\');return false;';
  var div = '<div class="input">';
  div = div + '<a href="#" class="definition-link" onclick="' + onclick + '">';
  div = div + title + '</a></div>';
  $('#api_selector').append(div);
};

var pathsort = function (paths, sep) {
  sep = sep || '/';

  return paths.map(function(el) {
    return el.split(sep);
  }).sort(sorter).map(function(el) {
    return el.join(sep);
  })
};

var sorter = function (a, b) {
  var l = Math.max(a.length, b.length);
  for (var i = 0; i < l; i += 1) {
    if (!(i in a)) return -1;
    if (!(i in b)) return +1;
    if (a[i].toUpperCase() > b[i].toUpperCase()) return +1;
    if (a[i].toUpperCase() < b[i].toUpperCase()) return -1;
    if (a.length < b.length) return -1;
    if (a.length > b.length) return +1;
  }
};

$(function () {
  hljs.configure({
    highlightSizeThreshold: 5000
  });

  // Pre load translate...
  if (window.SwaggerTranslator) {
    window.SwaggerTranslator.translate();
  }

  $.getJSON("/definitions/list.json", function(definitionFiles) {
    definitionFiles = pathsort(definitionFiles);
    definitionFiles.forEach(appendDefinitionLink);
    loadJson(definitionFiles[0]);
  });

  function log() {
    if ('console' in window) {
      console.log.apply(console, arguments);
    }
  }
});