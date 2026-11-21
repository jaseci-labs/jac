impl TransportResponse.success(
    data: any = None,
    msg_type: (MessageType | str) = MessageType.RESPONSE.value,
    meta: (Meta | None) = None
) -> TransportResponse {
    final_meta = meta or Meta();
    response = TransportResponse();
    response.type = msg_type.value if isinstance(msg_type, MessageType) else msg_type;
    response.ok = True;
    response.data = data;
    response.error = None;
    response.meta = final_meta;
    return response;
}

impl TransportResponse.fail(
    code: str,
    message: str,
    details: any = None,
    msg_type: (MessageType | str) = MessageType.ERROR.value,
    meta: (Meta | None) = None
) -> TransportResponse {
    final_meta = meta or Meta();
    response = TransportResponse();
    response.type = msg_type.value if isinstance(msg_type, MessageType) else msg_type;
    response.ok = False;
    response.data = None;
    response.error = ErrorInfo(code=code, message=message, details=details);
    response.meta = final_meta;
    return response;
}
