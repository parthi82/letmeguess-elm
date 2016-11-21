module Main exposing (..)

import Html exposing (Html, div, ul, li, text, Attribute, input)
import Html.Events exposing (on, keyCode, onInput)
import Html.Attributes exposing (value)
import List
import Json.Decode as JD
import Json.Encode as JE
import Phoenix.Socket as Socket
import Phoenix.Channel as Channel
import Phoenix.Push as Push
import Phoenix exposing (connect, push)


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
    | NewMsg JE.Value



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
                let
                    payload =
                        JE.object [ ( "msg", JE.string model.messageText ) ]

                    message =
                        Push.init "room:lobby" "new_msg"
                            |> Push.withPayload payload
                in
                    ( { model | messageText = "" }, push socketUrl message )
            else
                ( model, Cmd.none )

        Input txt ->
            ( { model | messageText = txt }, Cmd.none )

        NewMsg raw ->
            case JD.decodeValue (JD.field "msg" JD.string) raw of
                Ok msg ->
                    ( { model | messages = model.messages ++ [ msg ] }, Cmd.none )

                Err err ->
                    ( { model | messages = model.messages ++ [ "msg not sent" ] }, Cmd.none )



-- SUBCRIPTIONS


socketUrl : String
socketUrl =
    "ws://localhost:4000/socket/websocket"


socket =
    Socket.init socketUrl


channel =
    Channel.init "room:lobby"
        |> Channel.on "new_msg" NewMsg
        |> Channel.withDebug


subscriptions : Model -> Sub Msg
subscriptions model =
    connect socket [ channel ]


onKeyDown : (Int -> msg) -> Attribute msg
onKeyDown tagger =
    on "keydown" (JD.map tagger keyCode)



-- MAIN


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
