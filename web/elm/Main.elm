module Main exposing (..)

import Html exposing (Html, div, ul, li, text, Attribute, input)
import Html.Events exposing (on, keyCode, onInput)
import Html.Attributes exposing (value)
import List
import Json.Decode as Json
import Html.App


-- MODEL


type alias Model =
    { messages : List String
    , messageText : String
    }


init : ( Model, Cmd Msg )
init =
    ( Model [] "", Cmd.none )



-- ( { messages = [ "Hi" ], messageText = "" }, Cmd.none )
-- MESSAGES


type Msg
    = KeyDown Int
    | Input String



-- VIEW


messageView : String -> Html Msg
messageView message =
    li [] [ text message ]


view : Model -> Html Msg
view { messages, messageText } =
    div []
        [ ul [] (List.map messageView messages)
        , input [ onInput Input, onKeyDown KeyDown, value messageText ] []
        ]



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        KeyDown key ->
            if key == 13 then
                ( { model
                    | messages = model.messages ++ [ model.messageText ]
                    , messageText = ""
                  }
                , Cmd.none
                )
            else
                ( model, Cmd.none )

        Input txt ->
            ( { model | messageText = txt }, Cmd.none )



-- SUBCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown tagger =
    on "keydown" (Json.map tagger keyCode)



-- MAIN


main : Program Never
main =
    Html.App.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
