"""The Argument Clinic signatures of syslog.

scripts/jacpython/gen_clinic.jac generates
jaclang/runtime/python/bindings/clinic/syslog.jac from them. Taken from
the C sources it replaces (Modules/syslogmodule.c); see
jac/jaclang/runtime/python/LICENSE.cpython.
"""
import from clinic_schema { Clinic, Function, Parameter }

glob CLINIC: Clinic = Clinic(
         module="syslog",
         version="3.14.6",
         sources=["Modules/syslogmodule.c"],
         functions=[
             Function(
                 name="openlog",
                 full_name="syslog.openlog",
                 c_basename="syslog_openlog",
                 docstring="openlog($module, /, ident=<unrepresentable>, logoption=0,\n"
                 "        facility=LOG_USER)\n"
                 "--\n"
                 "\n"
                 "Set logging options of subsequent syslog() calls.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="ident",
                         converter="unicode",
                         format_unit="U",
                         default_kind="NULL",
                         c_default="NULL"
                     ),
                     Parameter(
                         name="logoption",
                         converter="long",
                         type="long",
                         format_unit="l",
                         default_kind="value",
                         py_default=0,
                         c_default="0"
                     ),
                     Parameter(
                         name="facility",
                         converter="long",
                         type="long",
                         format_unit="l",
                         default_kind="unknown",
                         c_default="LOG_USER"
                     )
                 ],
                 flags="METH_FASTCALL|METH_KEYWORDS",
                 parser="PARSE_KEYWORDS",
                 max_pos=3
             ),
             Function(
                 name="syslog",
                 full_name="syslog.syslog",
                 c_basename="syslog_syslog",
                 docstring="syslog([priority=LOG_INFO,] message)\n"
                 "Send the string message to the system logger.",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="priority",
                         kind="POSITIONAL_ONLY",
                         converter="int",
                         type="int",
                         format_unit="i",
                         default_kind="unknown",
                         c_default="LOG_INFO",
                         group=-1
                     ),
                     Parameter(
                         name="message",
                         kind="POSITIONAL_ONLY",
                         converter="str",
                         type="const char *",
                         format_unit="s"
                     )
                 ],
                 flags="METH_VARARGS",
                 parser="parser for METH_VARARGS",
                 min_pos=2,
                 max_pos=2,
                 pos_only=2
             ),
             Function(
                 name="closelog",
                 full_name="syslog.closelog",
                 c_basename="syslog_closelog",
                 docstring="closelog($module, /)\n"
                 "--\n"
                 "\n"
                 "Reset the syslog module values and call the system library closelog().",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     )
                 ],
                 flags="METH_NOARGS",
                 parser="PARSE_GIVEN"
             ),
             Function(
                 name="setlogmask",
                 full_name="syslog.setlogmask",
                 c_basename="syslog_setlogmask",
                 docstring="setlogmask($module, maskpri, /)\n"
                 "--\n"
                 "\n"
                 "Set the priority mask to maskpri and return the previous mask value.",
                 returns="long",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="maskpri",
                         kind="POSITIONAL_ONLY",
                         converter="long",
                         type="long",
                         format_unit="l"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="LOG_MASK",
                 full_name="syslog.LOG_MASK",
                 c_basename="syslog_LOG_MASK",
                 docstring="LOG_MASK($module, pri, /)\n"
                 "--\n"
                 "\n"
                 "Calculates the mask for the individual priority pri.",
                 returns="long",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pri",
                         kind="POSITIONAL_ONLY",
                         converter="long",
                         type="long",
                         format_unit="l"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             ),
             Function(
                 name="LOG_UPTO",
                 full_name="syslog.LOG_UPTO",
                 c_basename="syslog_LOG_UPTO",
                 docstring="LOG_UPTO($module, pri, /)\n"
                 "--\n"
                 "\n"
                 "Calculates the mask for all priorities up to and including pri.",
                 returns="long",
                 params=[
                     Parameter(
                         name="module",
                         kind="POSITIONAL_ONLY",
                         converter="self",
                         type=""
                     ),
                     Parameter(
                         name="pri",
                         kind="POSITIONAL_ONLY",
                         converter="long",
                         type="long",
                         format_unit="l"
                     )
                 ],
                 flags="METH_O",
                 parser="PARSE_GIVEN",
                 min_pos=1,
                 max_pos=1,
                 pos_only=1
             )
         ]
     );
