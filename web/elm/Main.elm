module Main exposing (..)

import Html exposing (Html, programWithFlags, div, ul, li, text, Attribute, input, button, h4, p)
import Html.Events exposing (on, keyCode, onInput, onClick)
import Html.Attributes exposing (class, id)
import List
import Json.Decode as JD
import Json.Encode as JE
import Phoenix.Socket as Socket
import Phoenix.Channel as Channel
import Phoenix.Push as Push
import Phoenix exposing (connect, push)
import Material
import Material.Elevation as Elevation
import Material.Color as Color
import Material.Layout as Layout
import Material.Textfield as Textfield
import Material.List as Lists
import Material.Button as Button
import Material.Options as Options exposing (css)
import Material.Grid exposing (grid, cell, size, offset, Device(..))
import Material.Card as Card


white : Options.Property c m
white =
    Color.text Color.white



-- MODEL


type alias Model =
    { mdl : Material.Model
    , messages : List ChatMsg
    , messageText : String
    , flags : Flags
    , gameState : GameState
    , userName : String
    }


type alias Flags =
    { roomUrl : String
    , socketUrl : String
    , channel : String
    }


type alias ChatMsg =
    { user : String
    , msg : String
    , msgType : String
    }


type GameState
    = NotStarted
    | Started
    | Ended


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( Model Material.model [] "" flags NotStarted "", Cmd.none )



-- MESSAGES


type Msg
    = Mdl (Material.Msg Msg)
    | NameInput String
    | StartGame
    | ChatInput String
    | NewMsg JE.Value
    | SendMsg



-- VIEW


messageView : ChatMsg -> Html Msg
messageView payload =
    if payload.msgType == "user_msg" then
        li [] [ text (payload.user ++ ": " ++ payload.msg) ]
    else if payload.msgType == "joined" then
        li [] [ text (payload.user ++ " has joined") ]
    else
        li [] [ text (payload.user ++ " has left") ]


scoreView : Html a
scoreView =
    div [ id "score_view" ]
        [ h4 [] [ text "Cell 1" ]
        , p [] [ text "This cell is offset by 2" ]
        ]


drawingView : Html a
drawingView =
    div [ id "drawing_view" ]
        [ h4 [] [ text "Cell 2" ] ]


chatView : Material.Model -> Html Msg
chatView mdl =
    div []
        [ Card.view
            [ Elevation.e2
            , css "min-height" "70%"
            ]
            [ Card.actions []
                [ Lists.ul []
                    [ Lists.li [] [ Lists.content [] [ text "Elm" ] ]
                    , Lists.li [] [ Lists.content [] [ text "F#" ] ]
                    , Lists.li [] [ Lists.content [] [ text "Lisp" ] ]
                    ]
                ]
            ]
        , Card.view
            [ --  css "width"
              --     "128px"
              -- , Color.background
              --     (Color.color Color.Blue Color.S500)
              -- , Color.background (Color.color Color.Pink Color.S500)
              -- Click
              -- , Options.onClick Click
              -- Elevation
              Elevation.e2
            , css "min-height" "10%"
            ]
            [ Card.actions []
                [ Textfield.render Mdl [ 1 ] mdl [ Textfield.label "Type here", Options.onInput ChatInput ] []
                ]
            ]
        ]


gameView mdl =
    div [ id "game_view" ]
        [ scoreView
        , drawingView
        , chatView mdl
        ]


view : Model -> Html Msg
view { mdl, messages, messageText, gameState } =
    case gameState of
        NotStarted ->
            div []
                [ (text " Enter your Nick name : ")
                , input [ onInput NameInput, onEnter StartGame ] []
                , button [ onClick StartGame ] [ text "Play" ]
                ]

        Started ->
            div []
                [ Layout.render Mdl
                    mdl
                    [ Layout.fixedHeader, css "min-height" "100%" ]
                    { header = [ Layout.title [] [ text "Letmeguess" ] ]
                    , drawer = []
                    , tabs = ( [], [] )
                    , main =
                        [ gameView mdl ]
                    }
                ]

        Ended ->
            div [] [ text "Game Ended!" ]


onEnter : Msg -> Attribute Msg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                JD.succeed msg
            else
                JD.fail "not ENTER"
    in
        on "keydown" (JD.andThen isEnter keyCode)



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NameInput txt ->
            ( { model | userName = txt }, Cmd.none )

        StartGame ->
            if model.userName == "" then
                ( model, Cmd.none )
            else
                ( { model | gameState = Started }, Cmd.none )

        SendMsg ->
            let
                payload =
                    JE.object [ ( "msg", JE.string model.messageText ) ]

                message =
                    Push.init model.flags.channel "new_msg"
                        |> Push.withPayload payload
            in
                ( { model | messageText = "" }, push model.flags.socketUrl message )

        ChatInput txt ->
            ( { model | messageText = txt }, Cmd.none )

        NewMsg raw ->
            case JD.decodeValue decodeChatMsg raw of
                Ok msg ->
                    ( { model | messages = model.messages ++ [ msg ] }, Cmd.none )

                Err err ->
                    ( model, Cmd.none )

        -- Boilerplate: Mdl action handler.
        Mdl msg_ ->
            Material.update Mdl msg_ model


decodeChatMsg : JD.Decoder ChatMsg
decodeChatMsg =
    JD.map3 ChatMsg (JD.field "user" JD.string) (JD.field "msg" JD.string) (JD.field "type" JD.string)



-- SUBCRIPTIONS


socket : String -> Socket.Socket Msg
socket socketUrl =
    Socket.init socketUrl


channel : String -> String -> Channel.Channel Msg
channel channelId userName =
    Channel.init channelId
        |> Channel.withPayload (JE.object [ ( "user_name", JE.string userName ) ])
        |> Channel.on "new_msg" NewMsg
        |> Channel.withDebug


subscriptions : Model -> Sub Msg
subscriptions { mdl, flags, gameState, userName } =
    case gameState of
        Started ->
            Sub.batch
                [ Layout.subs Mdl mdl
                , connect (socket flags.socketUrl) [ (channel flags.channel userName) ]
                ]

        NotStarted ->
            Sub.batch
                [ Layout.subs Mdl mdl
                , connect (socket flags.socketUrl) []
                ]

        Ended ->
            Sub.batch
                [ Layout.subs Mdl mdl
                , connect (socket flags.socketUrl) []
                ]



-- MAIN


main : Program Flags Model Msg
main =
    programWithFlags
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
