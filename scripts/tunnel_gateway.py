import argparse
import mimetypes
from pathlib import Path

from aiohttp import ClientSession, WSMsgType, web


def resolve_static_file(root: Path, request_path: str) -> Path | None:
    path = request_path.lstrip("/")
    if path in {"", "frontend", "mobile"}:
        path = f"{path or 'frontend'}/index.html"
    elif path.startswith("frontend/") and request_path.endswith("/"):
        path = f"{path}index.html"
    elif path.startswith("mobile/") and request_path.endswith("/"):
        path = f"{path}index.html"

    candidate = (root / path).resolve()
    if root not in candidate.parents and candidate != root:
        return None
    if candidate.is_dir():
        candidate = candidate / "index.html"
    if candidate.exists():
        return candidate

    if path.startswith("frontend/"):
        return root / "frontend" / "index.html"
    if path.startswith("mobile/"):
        return root / "mobile" / "index.html"
    return None


async def proxy_http(request: web.Request) -> web.StreamResponse:
    target = request.app["backend"] + request.rel_url.path_qs
    headers = {
        key: value
        for key, value in request.headers.items()
        if key.lower() not in {"host", "content-length"}
    }
    body = await request.read()
    async with request.app["session"].request(
        request.method,
        target,
        headers=headers,
        data=body,
        allow_redirects=False,
    ) as response:
        response_headers = {
            key: value
            for key, value in response.headers.items()
            if key.lower() not in {"content-encoding", "transfer-encoding"}
        }
        return web.Response(
            status=response.status,
            headers=response_headers,
            body=await response.read(),
        )


async def proxy_ws(request: web.Request) -> web.WebSocketResponse:
    ws_server = web.WebSocketResponse()
    await ws_server.prepare(request)
    backend_ws = request.app["backend"].replace("http://", "ws://").replace(
        "https://", "wss://"
    )
    target = backend_ws + request.rel_url.path_qs

    async with request.app["session"].ws_connect(target, headers=request.headers) as ws_client:
        async def to_backend():
            async for message in ws_server:
                if message.type == WSMsgType.TEXT:
                    await ws_client.send_str(message.data)
                elif message.type == WSMsgType.BINARY:
                    await ws_client.send_bytes(message.data)
                elif message.type == WSMsgType.CLOSE:
                    await ws_client.close()

        async def to_client():
            async for message in ws_client:
                if message.type == WSMsgType.TEXT:
                    await ws_server.send_str(message.data)
                elif message.type == WSMsgType.BINARY:
                    await ws_server.send_bytes(message.data)
                elif message.type == WSMsgType.CLOSE:
                    await ws_server.close()

        await request.app["asyncio"].gather(to_backend(), to_client())
    return ws_server


async def static_or_proxy(request: web.Request) -> web.StreamResponse:
    if request.path.startswith(("/api/", "/admin/", "/static/")):
        return await proxy_http(request)
    if request.path.startswith("/ws/"):
        return await proxy_ws(request)

    file_path = resolve_static_file(request.app["static_root"], request.path)
    if file_path is None:
        raise web.HTTPNotFound()
    content_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
    return web.FileResponse(file_path, headers={"Content-Type": content_type})


async def create_app(args: argparse.Namespace) -> web.Application:
    import asyncio

    app = web.Application()
    app["asyncio"] = asyncio
    app["backend"] = args.backend.rstrip("/")
    app["static_root"] = Path(args.static_root).resolve()
    app["session"] = ClientSession()
    app.router.add_route("*", "/{tail:.*}", static_or_proxy)

    async def close_session(app: web.Application) -> None:
        await app["session"].close()

    app.on_cleanup.append(close_session)
    return app


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3000)
    parser.add_argument("--backend", default="http://127.0.0.1:8000")
    parser.add_argument("--static-root", required=True)
    args = parser.parse_args()
    web.run_app(create_app(args), host=args.host, port=args.port)


if __name__ == "__main__":
    main()
