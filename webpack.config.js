module.exports = {
  entry: [
    "./web/static/js/app.js",
    "./web/elm/Main.elm"
  ],
  output: {
    path: "./priv/static/js",
    filename: "app.js"
  },
  module: {
    loaders: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        loader: "babel",
        query: {
          presets: ["es2015"]
        }
      },
      // add elm loader
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        loader: `elm-webpack?cwd=${__dirname}/web/elm`
      }
    ],
    // don't parse Elm files since they won't be using require or define calls
    noParse: [/\.elm$/]
  },
  resolve: {
    modulesDirectories: [
      "node_modules",
      __dirname + "/web/static/js"
    ],
    // We need webpack to know it can resolve elm files
    extensions: ['', '.scss', '.css', '.js', '.elm']
  }
}
