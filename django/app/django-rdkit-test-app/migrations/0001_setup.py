# -*- coding: utf-8 -*-
from django.db import migrations
from django_rdkit_test_app.operations import RDKitExtension

class Migration(migrations.Migration):

    dependencies = [
    ]

    operations = [
        RDKitExtension(),
    ]
