cl {
    def:pub Card(
        title: str,
        children: any
    ) -> any {
        return <div className="card">
            <h3 className="card-title">{title}</h3>
            <div className="card-body">
                {children}
            </div>
        </div>;
    }
}
