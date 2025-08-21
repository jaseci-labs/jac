# Jac-Streamlit Plugin
`pip install .` command in the `plugins/streamlit` installs the jac-streamlit, which creates CLI commands shown below, which are associated with jac streamlit.

## 1. To streamlit the specified .jac file.

```
jac streamlit [-h] filename
```
and

## 2. To visualize the jac graph of a specified .jac file.

```
jac dot_view [-h] filename
```
## Examlpe Usage
>### Below is examlpe.jac using jac's data spatial features
>```
>walker Creator {
>    can create with `root entry;
>}
>node node_a {
>    has val: int;
>}
>:walker:Creator:can:create {
>    end = here;
>   for i=0 to i<3 by i+=1  {
>        end ++> (end := node_a(val=i + 1));
>    }
>    visit [-->];
>    for i=0 to i<3 by i+=1  {
>        here ++> node_a(val=i + 1);
>    }
>}
>with entry {
>    root spawn Creator();
>}
>```
>
>### Output of `jac dot_view examlpe.jac`
>### With Interactive View
>![Interactive](./assets/interactive%20view.png)
>### With Static View
>![Static](./assets/static%20view.png)
