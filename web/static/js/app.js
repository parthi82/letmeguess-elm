import Elm from '../../elm/Main';
const { host, pathname, href: roomUrl } = window.location;
const channel = `room:${pathname.replace('/', '')}`;
const socketUrl = `ws://${host}/socket/websocket`
Elm.Main.embed(document.getElementById('elm-app'), {channel, socketUrl, roomUrl});
