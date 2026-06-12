import flet as ft
import requests

def DashboardView(page: ft.Page, on_logout):
    token = page.client_storage.get("token")
    headers = {"Authorization": f"Bearer {token}"}
    api_url = "http://127.0.0.1:7000/api"

    content_area = ft.Container(expand=True, padding=20)

    def cargar_vista_marcas():
        nombre_input = ft.TextField(label="Nombre de la Marca", width=300)
        msg_text = ft.Text()
        lista_marcas = ft.ListView(expand=True, spacing=10, max_height=300)

        def actualizar_lista_marcas():
            lista_marcas.controls.clear()
            try:
                res = requests.get(f"{api_url}/inventario/marcas", headers=headers)
                if res.status_code == 200:
                    for marca in res.json():
                        lista_marcas.controls.append(
                            ft.ListTile(
                                leading=ft.Icon(ft.Icons.FACTORY, color=ft.Colors.BLUE_400),
                                title=ft.Text(marca["nombre"]),
                                subtitle=ft.Text(f"ID: {marca['id']}")
                            )
                        )
                page.update()
            except: pass

        def guardar_marca_click(e):
            if not nombre_input.value: return
            try:
                res = requests.post(f"{api_url}/inventario/marcas", json={"nombre": nombre_input.value}, headers=headers)
                if res.status_code == 201:
                    nombre_input.value = ""
                    actualizar_lista_marcas()
                page.update()
            except: pass

        actualizar_lista_marcas()
        content_area.content = ft.Column([
            ft.Text("Gestión de Marcas", size=22, weight=ft.FontWeight.BOLD),
            ft.Row([nombre_input, ft.ElevatedButton("Guardar", on_click=guardar_marca_click)]),
            lista_marcas
        ])
        page.update()

    def menu_cambiado(e):
        if e.control.selected_index == 0: cargar_vista_marcas()
        elif e.control.selected_index == 3: 
            page.client_storage.remove("token")
            on_logout()

    sidebar = ft.NavigationRail(
        selected_index=0,
        destinations=[
            ft.NavigationRailDestination(icon=ft.Icons.FACTORY_OUTLINED, selected_icon=ft.Icons.FACTORY, label="Marcas"),
            ft.NavigationRailDestination(icon=ft.Icons.COMPUTER_OUTLINED, selected_icon=ft.Icons.COMPUTER, label="Equipos"),
            ft.NavigationRailDestination(icon=ft.Icons.ASSIGNMENT_IND_OUTLINED, selected_icon=ft.Icons.ASSIGNMENT_IND, label="Asignaciones"),
            ft.NavigationRailDestination(icon=ft.Icons.LOGOUT, label="Salir"),
        ],
        on_change=menu_cambiado
    )

    cargar_vista_marcas()
    return ft.Row([sidebar, ft.VerticalDivider(), content_area], expand=True)