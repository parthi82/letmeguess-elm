const path = require('path');

module.exports = {
  entry: [
    "./web/static/js/app.js",
    "./web/elm/Main.elm"
  ],
  output: {
    path: path.resolve(__dirname, './priv/static/js'),
    filename: "app.js"
  },
  module: {
    loaders: [
      {
        test: /\.(css|scss)$/,
        use: [
          'style-loader',
          'css-loader',
        ]
      },
      {
        test: /\.css$/,
        loaders: ['style', 'css', 'sass']
      },
      {
        test: /\.scss$/,
        loaders: ['style', 'css', 'sass']
      },
      {
          test: /\.jsx?$/,
          exclude: /(node_modules|bower_components)/,
          loader: 'babel-loader',
          options: {
            presets: ['latest'],
          },
      },
      {
        test: /\.(woff|woff2)(\?v=\d+\.\d+\.\d+)?$/, loader: 'url?limit=10000&mimetype=application/font-woff'
      },
      {
        test: /\.ttf(\?v=\d+\.\d+\.\d+)?$/, loader: 'url?limit=10000&mimetype=application/octet-stream'
      },
      {
        test: /\.eot(\?v=\d+\.\d+\.\d+)?$/, loader: 'file'
      },
      {
        test: /\.svg(\?v=\d+\.\d+\.\d+)?$/, loader: 'url?limit=10000&mimetype=image/svg+xml'
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        loader: `elm-webpack-loader?verbose=true&warn=true&debug=true&cwd=${__dirname}/web/elm`
      }
    ],
    // don't parse Elm files since they won't be using require or define calls
    noParse: [/\.elm$/]
  },

  resolve: {
    extensions: ['*', '.scss', '.css', '.js', '.elm'],
    modules: ['node_modules'],
  }
}
