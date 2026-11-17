package example

import com.sun.net.httpserver.HttpServer

import java.net.InetSocketAddress
import java.nio.charset.StandardCharsets

/** Answers every request on port 8080 with a greeting. */
object HelloWorld {

  def greeting(name: String): String = s"Hello, $name!"

  def main(args: Array[String]): Unit = {
    val server = HttpServer.create(new InetSocketAddress(8080), 0)
    server.createContext(
      "/",
      exchange => {
        val body = greeting("world").getBytes(StandardCharsets.UTF_8)
        exchange.sendResponseHeaders(200, body.length)
        exchange.getResponseBody.write(body)
        exchange.close()
      }
    )
    server.start()
    println("Listening on port 8080")
  }
}
