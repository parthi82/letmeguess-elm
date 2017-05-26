module Main exposing (..)

import Html exposing (Html, programWithFlags, div, ul, li, text, Attribute, input, button, h4, p)
import Html.Events exposing (on, keyCode, onInput, onClick)
import Html.Attributes exposing (class, id, style)
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
import Material.Options as Options exposing (css)
import Material.Card as Card
import Collage exposing (defaultLine)
import Element exposing (toHtml)
import Mouse exposing (Position)
import Dom.Scroll as Scroll
import Task


-- import Material.Button as Button


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
    , isDraging : Bool
    , paths : List (List Position)
    , word : List String
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
    ( Model Material.model [] "" flags NotStarted "" False [] [], Cmd.none )



-- MESSAGES


type Msg
    = Mdl (Material.Msg Msg)
    | NameInput String
    | StartGame
    | ChatInput String
    | NewMsg JE.Value
    | SendMsg
    | MouseDown Position
    | MouseUp Position
    | MouseMoved Position
    | NoOp



-- VIEW
-- messageView : ChatMsg -> Html Msg


messagText : String -> Html msg
messagText txt =
    Lists.li [] [ div [ class "chat_item" ] [ text (txt) ] ]


messageView : ChatMsg -> Html msg
messageView payload =
    if payload.msgType == "user_msg" then
        messagText (payload.user ++ ": " ++ payload.msg)
    else if payload.msgType == "joined" then
        messagText (payload.user ++ " has joined")
    else
        messagText (payload.user ++ " has left")


scoreView : Html a
scoreView =
    div [ id "score_view" ]
        [ h4 [] [ text "score_view" ]
        , p [] [ text "This is score_view" ]
        ]


drawingView : Model -> Html Msg
drawingView model =
    let
        toPaths positions =
            Collage.path
                (List.map
                    (\{ x, y } ->
                        ( toFloat <| x
                        , toFloat <| -y
                        )
                    )
                    positions
                )
                |> Collage.traced
                    { defaultLine
                        | width = 5
                        , cap = Collage.Round
                        , join = Collage.Smooth
                    }
                |> Collage.move ( -594, 315 )
    in
        div
            [ id "drawing_view"
            , style
                [ ( "cursor", "pointer" )
                , ( "border", "2px solid black" )
                ]
            ]
            [ Collage.collage
                700
                500
                (List.map toPaths model.paths)
                |> toHtml
            ]


chatView : Model -> Html Msg
chatView model =
    div [ id "chat_view" ]
        [ Card.view
            [ Elevation.e2
            , css "overflow-y" "scroll"
            , css "height" "calc(100% - 75px)"
            , Options.id "chat_content"
            ]
            [ Card.actions []
                [ Lists.ul [] (List.map messageView model.messages)
                ]
            ]
        , Card.view
            [ Elevation.e16
            , css "min-height" "10%"
            ]
            [ Card.actions []
                [ Textfield.render Mdl
                    [ 1 ]
                    model.mdl
                    [ Textfield.label "Type here"
                    , Options.onInput ChatInput
                    , Options.on "keydown" (JD.andThen isEnter keyCode)
                    , Textfield.value model.messageText
                    ]
                    []
                ]
            ]
        ]


gameView : Model -> Html Msg
gameView model =
    div [ id "game_view" ]
        [ scoreView
        , drawingView model
        , chatView model
        ]


letterView : String -> Html Msg
letterView letter =
    if letter == "*" then
        li [ class "letter" ] [ text letter ]
    else
        li [ class "letter correct" ] [ text letter ]


wordView : List String -> Html Msg
wordView letters =
    ul [ class "word" ] (List.map letterView letters)


view : Model -> Html Msg
view model =
    case model.gameState of
        NotStarted ->
            div []
                [ (text " Enter your Nick name : ")
                , input [ onInput NameInput, onEnter StartGame ] []
                , button [ onClick StartGame ] [ text "Play" ]
                ]

        Started ->
            div []
                [ Layout.render Mdl
                    model.mdl
                    [ Layout.fixedHeader, css "min-height" "100%" ]
                    { header =
                        [ Layout.title [ Options.id "app_name" ]
                            [ text "Letmeguess" ]
                        , wordView model.word
                        ]
                    , drawer = []
                    , tabs = ( [], [] )
                    , main =
                        [ gameView model ]
                    }
                ]

        Ended ->
            div [] [ text "Game Ended!" ]


isEnter : number -> JD.Decoder Msg
isEnter code =
    if code == 13 then
        JD.succeed SendMsg
    else
        JD.fail "not Enter"


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
                    ( { model | messages = model.messages ++ [ msg ] }
                    , Task.attempt (always NoOp) <| Scroll.toBottom "chat_content"
                    )

                Err err ->
                    ( model, Cmd.none )

        MouseDown xy ->
            ( { model | isDraging = True, paths = [ xy ] :: model.paths }, Cmd.none )

        MouseUp xy ->
            ( { model | isDraging = False }, Cmd.none )

        MouseMoved xy ->
            if model.isDraging == True then
                case model.paths of
                    h :: t ->
                        ( { model | paths = (h ++ [ xy ]) :: t }, Cmd.none )

                    _ ->
                        ( model, Cmd.none )
            else
                ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )

        -- Boilerplate: Mdl action handler.
        Mdl msg_ ->
            Material.update Mdl msg_ model


decodeChatMsg : JD.Decoder ChatMsg
decodeChatMsg =
    JD.map3 ChatMsg
        (JD.field "user" JD.string)
        (JD.field "msg" JD.string)
        (JD.field "type" JD.string)



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
                , Mouse.downs MouseDown
                , Mouse.ups MouseUp
                , Mouse.moves MouseMoved
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
