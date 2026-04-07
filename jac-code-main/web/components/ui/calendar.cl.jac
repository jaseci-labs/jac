cl import from "react-day-picker" { DayPicker, getDefaultClassNames }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" {
    ArrowLeftIcon,
    ArrowRightIcon,
    ArrowDownIcon
}
cl import from .button { Button, buttonVariants }
cl import from ...lib.utils { cn }

cl {
    def CalendarChevron(props: Any) -> JsxElement {
        ori = props.orientation;
        icon = ArrowDownIcon;
        if ori == "left" { icon = ArrowLeftIcon; }
        elif ori == "right" { icon = ArrowRightIcon; }
        return <HugeiconsIcon
            icon={icon}
            {...props}
            className={cn("cn-rtl-flip size-4", props.className)}
            size={16}
        />;
    }

    def CalendarDayButton(props: Any) -> JsxElement {
        defaultClassNames2 = getDefaultClassNames();
        day = props.day;
        mm = props.modifiers;
        locale = props.locale;
        dateStr = "";
        if day and day.date {
            dateStr = day.date.toISOString().split("T")[0];
        }
        isSelectedSingle = mm and mm.selected and not mm.range_start and not mm.range_end and not mm.range_middle;
        return <Button
            {...props}
            variant="ghost"
            size="icon"
            data-day={dateStr}
            data-selected-single={isSelectedSingle}
            data-range-start={mm.range_start if mm else false}
            data-range-end={mm.range_end if mm else false}
            data-range-middle={mm.range_middle if mm else false}
            className={cn(
                "p-2 [--cell-radius:var(--radius-md)] [--cell-size:--spacing(7)]-day-button data-[selected-single=true]:bg-primary data-[selected-single=true]:text-primary-foreground data-[range-middle=true]:bg-muted data-[range-middle=true]:text-foreground data-[range-start=true]:bg-primary data-[range-start=true]:text-primary-foreground data-[range-end=true]:bg-primary data-[range-end=true]:text-primary-foreground relative isolate z-10 flex aspect-square size-auto w-full min-w-(--cell-size) flex-col gap-1 border-0 leading-none font-normal",
                defaultClassNames2.day,
                props.className
            )}
        />;
    }

    def CalendarWeekNumber(props: Any) -> JsxElement {
        return <td {...props}>
            <div className="flex size-(--cell-size) items-center justify-center text-center">
                {props.children}
            </div>
        </td>;
    }

    def CalendarRoot(props: Any) -> JsxElement {
        return <div
            data-slot="calendar"
            ref={props.rootRef}
            {...props}
            className={cn(props.className)}
        />;
    }

    def:pub Calendar(props: Any) -> JsxElement {
        showOutsideDays = true if props.showOutsideDays == None else props.showOutsideDays;
        captionLayout = props.captionLayout or "label";
        buttonVariant = props.buttonVariant or "ghost";
        locale = props.locale;
        defaultClassNames = getDefaultClassNames();
        variantsFn = buttonVariants();
        btnClass = variantsFn.call(None, {"variant": buttonVariant});
        captionIsLabel = captionLayout == "label";
        captionLabelClass = "select-none font-medium text-sm" if captionIsLabel else "h-6 pr-1 pl-1.5 rounded-(--cell-radius) flex items-center gap-1 text-sm select-none font-medium [&>svg]:text-muted-foreground [&>svg]:size-3.5";
        dayPickerClassNames = {
            root: cn("w-fit", defaultClassNames.root),
            months: cn("flex gap-4 flex-col md:flex-row relative", defaultClassNames.months),
            month: cn("flex flex-col w-full gap-4", defaultClassNames.month),
            nav: cn("flex items-center gap-1 w-full absolute top-0 inset-x-0 justify-between", defaultClassNames.nav),
            button_previous: cn(btnClass, "size-(--cell-size) aria-disabled:opacity-50 p-0 select-none", defaultClassNames.button_previous),
            button_next: cn(btnClass, "size-(--cell-size) aria-disabled:opacity-50 p-0 select-none", defaultClassNames.button_next),
            month_caption: cn("flex items-center justify-center h-(--cell-size) w-full px-(--cell-size)", defaultClassNames.month_caption),
            caption_label: cn(captionLabelClass, defaultClassNames.caption_label),
            table: "w-full border-collapse",
            weekdays: cn("flex", defaultClassNames.weekdays),
            weekday: cn("text-muted-foreground rounded-(--cell-radius) flex-1 font-normal text-[0.8rem] select-none", defaultClassNames.weekday),
            week: cn("flex w-full mt-2", defaultClassNames.week),
            day: cn("relative w-full rounded-(--cell-radius) h-full p-0 text-center group/day aspect-square select-none", defaultClassNames.day),
            today: cn("bg-muted text-foreground rounded-(--cell-radius)", defaultClassNames.today),
            outside: cn("text-muted-foreground", defaultClassNames.outside),
            disabled: cn("text-muted-foreground opacity-50", defaultClassNames.disabled),
            hidden: cn("invisible", defaultClassNames.hidden)
        };
        dayButtonFn = lambda(p: Any) -> Any { return <CalendarDayButton locale={locale} {...p} />; };
        calendarComponents = {
            Root: CalendarRoot,
            Chevron: CalendarChevron,
            DayButton: dayButtonFn,
            WeekNumber: CalendarWeekNumber
        };
        return <DayPicker
            showOutsideDays={showOutsideDays}
            {...props}
            className={cn(
                "p-2 [--cell-radius:var(--radius-md)] [--cell-size:--spacing(7)] bg-background group/calendar in-data-[slot=card-content]:bg-transparent in-data-[slot=popover-content]:bg-transparent",
                props.className
            )}
            captionLayout={captionLayout}
            classNames={dayPickerClassNames}
            components={calendarComponents}
        />;
    }
}
