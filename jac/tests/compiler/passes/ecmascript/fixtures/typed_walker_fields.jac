"""Fixture: CL sends typed objects as walker has fields.

Tests that when client code spawns a walker with typed has fields,
the objects are serialized with type metadata on the CL side and
deserialized on the SV side.
"""

obj DateRange {
    has start: str,
        end: str;
}

obj QueryOptions {
    has date_range: DateRange,
        limit: int = 50,
        offset: int = 0,
        sort_by: str = "created";
}

node Event {
    has title: str,
        date: str,
        category: str = "";
}

walker search_events {
    has options: QueryOptions;

    can search with Root entry {
        visit [-->[?:Event]];
    }

    can collect with Event entry {
        report here;
    }
}

walker create_event {
    has title: str,
        date: str,
        category: str = "";

    can create with Root entry {
        evt = here ++> Event(
            title=self.title,
            date=self.date,
            category=self.category
        );
        report evt;
    }
}

cl {
    def:pub app -> JsxElement {
        has events: list = [];

        async def loadEvents -> None {
            opts = QueryOptions(
                date_range=DateRange(start="2025-01-01", end="2025-12-31"),
                limit=100
            );
            result = root spawn search_events(options=opts);
            events = result.reports;
        }

        async def addEvent(title: str, date: str) -> None {
            result = root spawn create_event(title=title, date=date);
            events = events + [result.reports[0][0]];
        }

        return <div>
            {[<div key={e.title}>{e.date}: {e.title}</div> for e in events]}
        </div>;
    }
}
