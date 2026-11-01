"""The Argument Clinic signatures of _socket.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/socket.jac from them. Taken from
CPython 3.14.6 Modules/socketmodule.c, Modules/getaddrinfo.c, Modules/getnameinfo.c.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="_socket",
         version="3.14.6",
         sources=[
             "Modules/socketmodule.c",
             "Modules/getaddrinfo.c",
             "Modules/getnameinfo.c"
         ],
         classes={"socket": "PySocketSockObject *"},
         functions=[
             Function(
                 name="ntohs",
                 full_name="_socket.ntohs",
                 c_basename="_socket_ntohs",
                 docstring="ntohs($module, integer, /)\n"
                 "--\n"
                 "\n"
                 "Convert a 16-bit unsigned integer from network to host byte order.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="integer",
                         kind="POSITIONAL_ONLY",
                         converter="uint16",
                         type="uint16_t",
                         format_unit="O&",
                         convert_with="_PyLong_UInt16_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="ntohl",
                 full_name="_socket.ntohl",
                 c_basename="_socket_ntohl",
                 docstring="ntohl($module, integer, /)\n"
                 "--\n"
                 "\n"
                 "Convert a 32-bit unsigned integer from network to host byte order.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="integer",
                         kind="POSITIONAL_ONLY",
                         converter="uint32",
                         type="uint32_t",
                         format_unit="O&",
                         convert_with="_PyLong_UInt32_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="htons",
                 full_name="_socket.htons",
                 c_basename="_socket_htons",
                 docstring="htons($module, integer, /)\n"
                 "--\n"
                 "\n"
                 "Convert a 16-bit unsigned integer from host to network byte order.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="integer",
                         kind="POSITIONAL_ONLY",
                         converter="uint16",
                         type="uint16_t",
                         format_unit="O&",
                         convert_with="_PyLong_UInt16_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="htonl",
                 full_name="_socket.htonl",
                 c_basename="_socket_htonl",
                 docstring="htonl($module, integer, /)\n"
                 "--\n"
                 "\n"
                 "Convert a 32-bit unsigned integer from host to network byte order.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="integer",
                         kind="POSITIONAL_ONLY",
                         converter="uint32",
                         type="uint32_t",
                         format_unit="O&",
                         convert_with="_PyLong_UInt32_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="inet_aton",
                 full_name="_socket.inet_aton",
                 c_basename="_socket_inet_aton",
                 docstring="inet_aton($module, ip_addr, /)\n"
                 "--\n"
                 "\n"
                 "Convert an IP address in string format (123.45.67.89) to the 32-bit packed binary format used in low-level network functions.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="ip_addr",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="inet_ntoa",
                 full_name="_socket.inet_ntoa",
                 c_basename="_socket_inet_ntoa",
                 docstring="inet_ntoa($module, packed_ip, /)\n"
                 "--\n"
                 "\n"
                 "Convert an IP address from 32-bit packed binary format to string format.",
                 condition="defined(HAVE_INET_NTOA)",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="packed_ip",
                         kind="POSITIONAL_ONLY",
                         converter="Py_buffer",
                         type="Py_buffer",
                         format_unit="y*",
                         c_default="{NULL, NULL}",
                         by_reference=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="if_nametoindex",
                 full_name="_socket.if_nametoindex",
                 c_basename="_socket_if_nametoindex",
                 docstring="if_nametoindex($module, oname, /)\n"
                 "--\n"
                 "\n"
                 "Returns the interface index corresponding to the interface name if_name.",
                 condition="(defined(HAVE_IF_NAMEINDEX) || defined(MS_WINDOWS))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="oname",
                         kind="POSITIONAL_ONLY",
                         converter="unicode_fs_encoded",
                         format_unit="O&",
                         c_default="NULL",
                         convert_with="PyUnicode_FSConverter",
                         releases=True
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="if_indextoname",
                 full_name="_socket.if_indextoname",
                 c_basename="_socket_if_indextoname",
                 docstring="if_indextoname($module, if_index, /)\n"
                 "--\n"
                 "\n"
                 "Returns the interface name corresponding to the interface index if_index.",
                 condition="(defined(HAVE_IF_NAMEINDEX) || defined(MS_WINDOWS))",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="if_index",
                         kind="POSITIONAL_ONLY",
                         converter="NET_IFINDEX",
                         type="NET_IFINDEX",
                         format_unit="O&",
                         convert_with="_PyLong_NetIfindex_Converter"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="close",
                 full_name="_socket.socket.close",
                 c_basename="_socket_socket_close",
                 cls="socket",
                 docstring="close($self, /)\n"
                 "--\n"
                 "\n"
                 "close()\n"
                 "\n"
                 "Close the socket.  It cannot be used after this call.",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="__init__",
                 full_name="_socket.socket.__init__",
                 c_basename="sock_initobj",
                 kind="METHOD_INIT",
                 cls="socket",
                 returns="int",
                 params=[
                     Parameter(
                         name="self", kind="POSITIONAL_ONLY", converter="self", type=""
                     ),
                     Parameter(
                         name="family",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     ),
                     Parameter(
                         name="type",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     ),
                     Parameter(
                         name="proto",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="value",
                         py_default=-1,
                         c_default="-1"
                     ),
                     Parameter(
                         name="fileno",
                         format_unit="O",
                         default_kind="NULL",
                         c_default="NULL"
                     )
                 ],
                 flags="METH_VARARGS|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=4
             )
         ],
         docs={
             "sock_doc": "socket(family=AF_INET, type=SOCK_STREAM, proto=0) -> socket object\n"
             "socket(family=-1, type=-1, proto=-1, fileno=None) -> socket object\n"
             "\n"
             "Open a socket of the given type.  The family argument specifies the\n"
             "address family; it defaults to AF_INET.  The type argument specifies\n"
             "whether this is a stream (SOCK_STREAM, this is the default)\n"
             "or datagram (SOCK_DGRAM) socket.  The protocol argument defaults to 0,\n"
             "specifying the default protocol.  Keyword arguments are accepted.\n"
             "The socket is created as non-inheritable.\n"
             "\n"
             "When a fileno is passed in, family, type and proto are auto-detected,\n"
             "unless they are explicitly set.\n"
             "\n"
             "A socket object represents one endpoint of a network connection.\n"
             "\n"
             "Methods of socket objects (keyword arguments not allowed):\n"
             "\n"
             "_accept() -- accept connection, returning new socket fd and client address\n"
             "bind(addr) -- bind the socket to a local address\n"
             "close() -- close the socket\n"
             "connect(addr) -- connect the socket to a remote address\n"
             "connect_ex(addr) -- connect, return an error code instead of an exception\n"
             "dup() -- return a new socket fd duplicated from fileno()\n"
             "fileno() -- return underlying file descriptor\n"
             "getpeername() -- return remote address [*]\n"
             "getsockname() -- return local address\n"
             "getsockopt(level, optname[, buflen]) -- get socket options\n"
             "gettimeout() -- return timeout or None\n"
             "listen([n]) -- start listening for incoming connections\n"
             "recv(buflen[, flags]) -- receive data\n"
             "recv_into(buffer[, nbytes[, flags]]) -- receive data (into a buffer)\n"
             "recvfrom(buflen[, flags]) -- receive data and sender's address\n"
             "recvfrom_into(buffer[, nbytes, [, flags]])\n"
             "  -- receive data and sender's address (into a buffer)\n"
             "sendall(data[, flags]) -- send all data\n"
             "send(data[, flags]) -- send data, may not send all of it\n"
             "sendto(data[, flags], addr) -- send data to a given address\n"
             "setblocking(bool) -- set or clear the blocking I/O flag\n"
             "getblocking() -- return True if socket is blocking, False if non-blocking\n"
             "setsockopt(level, optname, value[, optlen]) -- set socket options\n"
             "settimeout(None | float) -- set or clear the timeout\n"
             "shutdown(how) -- shut down traffic in one or both directions\n"
             "\n"
             " [*] not available on all platforms!",
             "accept_doc": "_accept() -> (integer, address info)\n"
             "\n"
             "Wait for an incoming connection.  Return a new socket file descriptor\n"
             "representing the connection, and the address of the client.\n"
             "For IP sockets, the address info is a pair (hostaddr, port).",
             "setblocking_doc": "setblocking(flag)\n"
             "\n"
             "Set the socket to blocking (flag is true) or non-blocking (false).\n"
             "setblocking(True) is equivalent to settimeout(None);\n"
             "setblocking(False) is equivalent to settimeout(0.0).",
             "getblocking_doc": "getblocking()\n"
             "\n"
             "Returns True if socket is in blocking mode, or False if it\n"
             "is in non-blocking mode.",
             "settimeout_doc": "settimeout(timeout)\n"
             "\n"
             "Set a timeout on socket operations.  'timeout' can be a float,\n"
             "giving in seconds, or None.  Setting a timeout of None disables\n"
             "the timeout feature and is equivalent to setblocking(1).\n"
             "Setting a timeout of zero is the same as setblocking(0).",
             "gettimeout_doc": "gettimeout() -> timeout\n"
             "\n"
             "Returns the timeout in seconds (float) associated with socket\n"
             "operations. A timeout of None indicates that timeouts on socket\n"
             "operations are disabled.",
             "setsockopt_doc": "setsockopt(level, option, value: int)\n"
             "setsockopt(level, option, value: buffer)\n"
             "setsockopt(level, option, None, optlen: int)\n"
             "\n"
             "Set a socket option.  See the Unix manual for level and option.\n"
             "The value argument can either be an integer, a string buffer, or\n"
             "None, optlen.",
             "getsockopt_doc": "getsockopt(level, option[, buffersize]) -> value\n"
             "\n"
             "Get a socket option.  See the Unix manual for level and option.\n"
             "If a nonzero buffersize argument is given, the return value is a\n"
             "string of that length; otherwise it is an integer.",
             "bind_doc": "bind(address)\n"
             "\n"
             "Bind the socket to a local address.  For IP sockets, the address is a\n"
             "pair (host, port); the host must refer to the local host. For raw packet\n"
             "sockets the address is a tuple (ifname, proto [,pkttype [,hatype [,addr]]])",
             "detach_doc": "detach()\n"
             "\n"
             "Close the socket object without closing the underlying file descriptor.\n"
             "The object cannot be used after this call, but the file descriptor\n"
             "can be reused for other purposes.  The file descriptor is returned.",
             "connect_doc": "connect(address)\n"
             "\n"
             "Connect the socket to a remote address.  For IP sockets, the address\n"
             "is a pair (host, port).",
             "connect_ex_doc": "connect_ex(address) -> errno\n"
             "\n"
             "This is like connect(address), but returns an error code (the errno value)\n"
             "instead of raising an exception when an error occurs.",
             "fileno_doc": "fileno() -> integer\n"
             "\n"
             "Return the integer file descriptor of the socket.",
             "getsockname_doc": "getsockname() -> address info\n"
             "\n"
             "Return the address of the local endpoint. The format depends on the\n"
             "address family. For IPv4 sockets, the address info is a pair\n"
             "(hostaddr, port). For IPv6 sockets, the address info is a 4-tuple\n"
             "(hostaddr, port, flowinfo, scope_id).",
             "getpeername_doc": "getpeername() -> address info\n"
             "\n"
             "Return the address of the remote endpoint.  For IP sockets, the address\n"
             "info is a pair (hostaddr, port).",
             "listen_doc": "listen([backlog])\n"
             "\n"
             "Enable a server to accept connections.  If backlog is specified, it must be\n"
             "at least 0 (if it is lower, it is set to 0); it specifies the number of\n"
             "unaccepted connections that the system will allow before refusing new\n"
             "connections. If not specified, a default reasonable value is chosen.",
             "recv_doc": "recv(buffersize[, flags]) -> data\n"
             "\n"
             "Receive up to buffersize bytes from the socket.  For the optional flags\n"
             "argument, see the Unix manual.  When no data is available, block until\n"
             "at least one byte is available or until the remote end is closed.  When\n"
             "the remote end is closed and all data is read, return the empty string.",
             "recv_into_doc": "recv_into(buffer, [nbytes[, flags]]) -> nbytes_read\n"
             "\n"
             "A version of recv() that stores its data into a buffer rather than creating\n"
             "a new string.  Receive up to buffersize bytes from the socket.  If buffersize\n"
             "is not specified (or 0), receive up to the size available in the given buffer.\n"
             "\n"
             "See recv() for documentation about the flags.",
             "recvfrom_doc": "recvfrom(buffersize[, flags]) -> (data, address info)\n"
             "\n"
             "Like recv(buffersize, flags) but also return the sender's address info.",
             "recvfrom_into_doc": "recvfrom_into(buffer[, nbytes[, flags]]) -> (nbytes, address info)\n"
             "\n"
             "Like recv_into(buffer[, nbytes[, flags]]) but also return the sender's address info.",
             "recvmsg_doc": "recvmsg(bufsize[, ancbufsize[, flags]]) -> (data, ancdata, msg_flags, address)\n"
             "\n"
             "Receive normal data (up to bufsize bytes) and ancillary data from the\n"
             "socket.  The ancbufsize argument sets the size in bytes of the\n"
             "internal buffer used to receive the ancillary data; it defaults to 0,\n"
             "meaning that no ancillary data will be received.  Appropriate buffer\n"
             "sizes for ancillary data can be calculated using CMSG_SPACE() or\n"
             "CMSG_LEN(), and items which do not fit into the buffer might be\n"
             "truncated or discarded.  The flags argument defaults to 0 and has the\n"
             "same meaning as for recv().\n"
             "\n"
             "The return value is a 4-tuple: (data, ancdata, msg_flags, address).\n"
             "The data item is a bytes object holding the non-ancillary data\n"
             "received.  The ancdata item is a list of zero or more tuples\n"
             "(cmsg_level, cmsg_type, cmsg_data) representing the ancillary data\n"
             "(control messages) received: cmsg_level and cmsg_type are integers\n"
             "specifying the protocol level and protocol-specific type respectively,\n"
             "and cmsg_data is a bytes object holding the associated data.  The\n"
             "msg_flags item is the bitwise OR of various flags indicating\n"
             "conditions on the received message; see your system documentation for\n"
             "details.  If the receiving socket is unconnected, address is the\n"
             "address of the sending socket, if available; otherwise, its value is\n"
             "unspecified.\n"
             "\n"
             "If recvmsg() raises an exception after the system call returns, it\n"
             "will first attempt to close any file descriptors received via the\n"
             "SCM_RIGHTS mechanism.",
             "recvmsg_into_doc": "recvmsg_into(buffers[, ancbufsize[, flags]]) -> (nbytes, ancdata, msg_flags, address)\n"
             "\n"
             "Receive normal data and ancillary data from the socket, scattering the\n"
             "non-ancillary data into a series of buffers.  The buffers argument\n"
             "must be an iterable of objects that export writable buffers\n"
             "(e.g. bytearray objects); these will be filled with successive chunks\n"
             "of the non-ancillary data until it has all been written or there are\n"
             "no more buffers.  The ancbufsize argument sets the size in bytes of\n"
             "the internal buffer used to receive the ancillary data; it defaults to\n"
             "0, meaning that no ancillary data will be received.  Appropriate\n"
             "buffer sizes for ancillary data can be calculated using CMSG_SPACE()\n"
             "or CMSG_LEN(), and items which do not fit into the buffer might be\n"
             "truncated or discarded.  The flags argument defaults to 0 and has the\n"
             "same meaning as for recv().\n"
             "\n"
             "The return value is a 4-tuple: (nbytes, ancdata, msg_flags, address).\n"
             "The nbytes item is the total number of bytes of non-ancillary data\n"
             "written into the buffers.  The ancdata item is a list of zero or more\n"
             "tuples (cmsg_level, cmsg_type, cmsg_data) representing the ancillary\n"
             "data (control messages) received: cmsg_level and cmsg_type are\n"
             "integers specifying the protocol level and protocol-specific type\n"
             "respectively, and cmsg_data is a bytes object holding the associated\n"
             "data.  The msg_flags item is the bitwise OR of various flags\n"
             "indicating conditions on the received message; see your system\n"
             "documentation for details.  If the receiving socket is unconnected,\n"
             "address is the address of the sending socket, if available; otherwise,\n"
             "its value is unspecified.\n"
             "\n"
             "If recvmsg_into() raises an exception after the system call returns,\n"
             "it will first attempt to close any file descriptors received via the\n"
             "SCM_RIGHTS mechanism.",
             "send_doc": "send(data[, flags]) -> count\n"
             "\n"
             "Send a data string to the socket.  For the optional flags\n"
             "argument, see the Unix manual.  Return the number of bytes\n"
             "sent; this may be less than len(data) if the network is busy.",
             "sendall_doc": "sendall(data[, flags])\n"
             "\n"
             "Send a data string to the socket.  For the optional flags\n"
             "argument, see the Unix manual.  This calls send() repeatedly\n"
             "until all data is sent.  If an error occurs, it's impossible\n"
             "to tell how much data has been sent.",
             "sendto_doc": "sendto(data[, flags], address) -> count\n"
             "\n"
             "Like send(data, flags) but allows specifying the destination address.\n"
             "For IP sockets, the address is a pair (hostaddr, port).",
             "sendmsg_doc": "sendmsg(buffers[, ancdata[, flags[, address]]]) -> count\n"
             "\n"
             "Send normal and ancillary data to the socket, gathering the\n"
             "non-ancillary data from a series of buffers and concatenating it into\n"
             "a single message.  The buffers argument specifies the non-ancillary\n"
             "data as an iterable of bytes-like objects (e.g. bytes objects).\n"
             "The ancdata argument specifies the ancillary data (control messages)\n"
             "as an iterable of zero or more tuples (cmsg_level, cmsg_type,\n"
             "cmsg_data), where cmsg_level and cmsg_type are integers specifying the\n"
             "protocol level and protocol-specific type respectively, and cmsg_data\n"
             "is a bytes-like object holding the associated data.  The flags\n"
             "argument defaults to 0 and has the same meaning as for send().  If\n"
             "address is supplied and not None, it sets a destination address for\n"
             "the message.  The return value is the number of bytes of non-ancillary\n"
             "data sent.",
             "sendmsg_afalg_doc": "sendmsg_afalg([msg], *, op[, iv[, assoclen[, flags=MSG_MORE]]])\n"
             "\n"
             "Set operation mode, IV and length of associated data for an AF_ALG\n"
             "operation socket.",
             "shutdown_doc": "shutdown(flag)\n"
             "\n"
             "Shut down the reading side of the socket (flag == SHUT_RD), the writing side\n"
             "of the socket (flag == SHUT_WR), or both ends (flag == SHUT_RDWR).",
             "gethostname_doc": "gethostname() -> string\n"
             "\n"
             "Return the current host name.",
             "sethostname_doc": "sethostname(name)\n" "\n" "Sets the hostname to name.",
             "gethostbyname_doc": "gethostbyname(host) -> address\n"
             "\n"
             "Return the IP address (a string of the form '255.255.255.255') for a host.",
             "ghbn_ex_doc": "gethostbyname_ex(host) -> (name, aliaslist, addresslist)\n"
             "\n"
             "Return the true host name, a list of aliases, and a list of IP addresses,\n"
             "for a host.  The host argument is a string giving a host name or IP number.",
             "gethostbyaddr_doc": "gethostbyaddr(host) -> (name, aliaslist, addresslist)\n"
             "\n"
             "Return the true host name, a list of aliases, and a list of IP addresses,\n"
             "for a host.  The host argument is a string giving a host name or IP number.",
             "getservbyname_doc": "getservbyname(servicename[, protocolname]) -> integer\n"
             "\n"
             "Return a port number from a service name and protocol name.\n"
             "The optional protocol name, if given, should be 'tcp' or 'udp',\n"
             "otherwise any protocol will match.",
             "getservbyport_doc": "getservbyport(port[, protocolname]) -> string\n"
             "\n"
             "Return the service name from a port number and protocol name.\n"
             "The optional protocol name, if given, should be 'tcp' or 'udp',\n"
             "otherwise any protocol will match.",
             "getprotobyname_doc": "getprotobyname(name) -> integer\n"
             "\n"
             "Return the protocol number for the named protocol.  (Rarely used.)",
             "close_doc": "close(integer) -> None\n"
             "\n"
             "Close an integer socket file descriptor.  This is like os.close(), but for\n"
             "sockets; on some platforms os.close() won't work for socket file descriptors.",
             "dup_doc": "dup(integer) -> integer\n"
             "\n"
             "Duplicate an integer socket file descriptor.  This is like os.dup(), but for\n"
             "sockets; on some platforms os.dup() won't work for socket file descriptors.",
             "socketpair_doc": "socketpair([family[, type [, proto]]]) -> (socket object, socket object)\n"
             "\n"
             "Create a pair of socket objects from the sockets returned by the platform\n"
             "socketpair() function.\n"
             "The arguments are the same as for socket() except the default family is\n"
             "AF_UNIX if defined on the platform; otherwise, the default is AF_INET.",
             "inet_pton_doc": "inet_pton(af, ip) -> packed IP address string\n"
             "\n"
             "Convert an IP address from string format to a packed string suitable\n"
             "for use with low-level network functions.",
             "inet_ntop_doc": "inet_ntop(af, packed_ip) -> string formatted IP address\n"
             "\n"
             "Convert a packed IP address of the given family to string format.",
             "getaddrinfo_doc": "getaddrinfo(host, port [, family, type, proto, flags])\n"
             "    -> list of (family, type, proto, canonname, sockaddr)\n"
             "\n"
             "Resolve host and port into addrinfo struct.",
             "getnameinfo_doc": "getnameinfo(sockaddr, flags) --> (host, port)\n"
             "\n"
             "Get host and port for a sockaddr.",
             "getdefaulttimeout_doc": "getdefaulttimeout() -> timeout\n"
             "\n"
             "Returns the default timeout in seconds (float) for new socket objects.\n"
             "A value of None indicates that new socket objects have no timeout.\n"
             "When the socket module is first imported, the default is None.",
             "setdefaulttimeout_doc": "setdefaulttimeout(timeout)\n"
             "\n"
             "Set the default timeout in seconds (float) for new socket objects.\n"
             "A value of None indicates that new socket objects have no timeout.\n"
             "When the socket module is first imported, the default is None.",
             "if_nameindex_doc": "if_nameindex()\n"
             "\n"
             "Returns a list of network interface information (index, name) tuples.",
             "CMSG_LEN_doc": "CMSG_LEN(length) -> control message length\n"
             "\n"
             "Return the total length, without trailing padding, of an ancillary\n"
             "data item with associated data of the given length.  This value can\n"
             "often be used as the buffer size for recvmsg() to receive a single\n"
             "item of ancillary data, but RFC 3542 requires portable applications to\n"
             "use CMSG_SPACE() and thus include space for padding, even when the\n"
             "item will be the last in the buffer.  Raises OverflowError if length\n"
             "is outside the permissible range of values.",
             "CMSG_SPACE_doc": "CMSG_SPACE(length) -> buffer size\n"
             "\n"
             "Return the buffer size needed for recvmsg() to receive an ancillary\n"
             "data item with associated data of the given length, along with any\n"
             "trailing padding.  The buffer space needed to receive multiple items\n"
             "is the sum of the CMSG_SPACE() values for their associated data\n"
             "lengths.  Raises OverflowError if length is outside the permissible\n"
             "range of values.",
             "socket_doc": "Implementation module for socket operations.\n"
             "\n"
             "See the socket module for documentation.",
             "sock_memberlist_family_doc": "the socket family",
             "sock_memberlist_type_doc": "the socket type",
             "sock_memberlist_proto_doc": "the socket protocol",
             "sock_getsetlist_timeout_doc": "the socket timeout"
         }
     );
