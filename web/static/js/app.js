import Elm from '../../elm/Main';
const { protocol, host, pathname, href: roomUrl } = window.location;
const channel = `room:${pathname.replace('/', '')}`;
const wsprotocol = protocol === 'https:'? 'wss:' : 'ws:';
const socketUrl = `${wsprotocol}//${host}/socket/websocket`
Elm.Main.embed(document.getElementById('elm-app'), {channel, socketUrl, roomUrl});
